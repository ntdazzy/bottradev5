// Nhật ký sự kiện: ghi file và giữ vài dòng gần nhất cho bảng điều khiển
#ifndef BOTVANG_JOURNAL_MQH
#define BOTVANG_JOURNAL_MQH

class CJournal
  {
private:
   bool              m_toFile;
   int               m_vnOffset;
   string            m_name;       // tên bot: đầu dòng log và thư mục file
   string            m_recent[4];

public:
   void              Init(bool toFile, int vnOffset, const string name = "BotVang")
     {
      m_toFile = toFile;
      m_vnOffset = vnOffset;
      m_name = name;
      for(int i = 0; i < 4; i++)
         m_recent[i] = "";
     }

   void              Add(const string event, const string detail)
     {
      datetime vn = TimeCurrent() + m_vnOffset * 3600;
      string line = TimeToString(vn, TIME_MINUTES) + " " + detail;
      for(int i = 3; i > 0; i--)
         m_recent[i] = m_recent[i - 1];
      m_recent[0] = line;
      Print("[", m_name, "] ", event, " | ", detail);
      if(!m_toFile)
         return;
      string day = TimeToString(vn, TIME_DATE);
      StringReplace(day, ".", "-");
      string name = m_name + "\\journal_" + _Symbol + "_" + day + ".csv";   // mỗi ký hiệu một file (nhiều biểu đồ ghi cùng lúc)
      int h = FileOpen(name, FILE_READ | FILE_WRITE | FILE_TXT | FILE_UNICODE | FILE_SHARE_READ);
      if(h == INVALID_HANDLE)
        {
         Print("[", m_name, "] journal_open_failed err=", GetLastError());
         return;
        }
      FileSeek(h, 0, SEEK_END);
      FileWriteString(h, TimeToString(vn, TIME_DATE | TIME_SECONDS) + ";" + event + ";" + detail + "\r\n");
      FileClose(h);
     }

   string            Recent(int i) { return i >= 0 && i < 4 ? m_recent[i] : ""; }
  };

#endif
