// Kiểm chứng độc lập kết quả của BotVangLab bằng dữ liệu thật trên terminal (không dùng code đo của Lab):
// với mỗi sự kiện thật trong su_kien.csv: (1) soát nến chạm theo điều 3; (2) lấy tick thật bằng
// CopyTicksRange và tính lại chạm +kB trước hay −1B trước (k = 1, 2, 3) trong 36 nến. In số khớp / lệch.
input string InpRun = "";               // Thư mục lần chạy trong Common\Files\BotVangLab
input int    InpMax = 400;              // Số sự kiện tối đa cần soát
input bool   InpCloseTerminal = false;  // Đóng MT5 khi xong (chạy tự động)

int Col(const string &head[], const string name)
  {
   for(int i = 0; i < ArraySize(head); i++)
      if(head[i] == name)
         return i;
   return -1;
  }

// Tính lại kết quả k trên tick thật: 1 thắng, 0 thua, 2 hết giờ, 3 cắt vì giờ nghỉ
void Recompute(const string sym, datetime barOpen, long entryMsc, int dir, double entry, double B, int &res[])
  {
   for(int k = 0; k < 3; k++)
      res[k] = -1;
   MqlTick t[];
   datetime end = barOpen + 36 * 300;
   int n = CopyTicksRange(sym, t, COPY_TICKS_ALL, (ulong)barOpen * 1000, (ulong)(end + 3 * 86400) * 1000);
   long last = 0;
   for(int i = 0; i < n; i++)
     {
      if(last > 0 && t[i].time_msc - last >= 1800000)
        {
         for(int k = 0; k < 3; k++)
            if(res[k] < 0)
               res[k] = 3;
         return;
        }
      last = t[i].time_msc;
      if(t[i].time >= end)
         break;
      if(t[i].time_msc <= entryMsc)
         continue;
      double move = ((dir > 0 ? t[i].bid : t[i].ask) - entry) * dir;
      if(move <= -B + 1e-9)
        {
         for(int k = 0; k < 3; k++)
            if(res[k] < 0)
               res[k] = 0;
         return;
        }
      for(int k = 0; k < 3; k++)
         if(res[k] < 0 && move >= (k + 1) * B - 1e-9)
            res[k] = 1;
      if(res[2] >= 0)
         return;
     }
   for(int k = 0; k < 3; k++)
      if(res[k] < 0)
         res[k] = 2;
  }

void OnStart()
  {
   string sym = "XAUUSDm";
   int h = FileOpen("BotVangLab\\" + InpRun + "\\su_kien.csv", FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_SHARE_READ, 0, CP_UTF8);
   if(h == INVALID_HANDLE)
     {
      Print("[LabVerify] khong_mo_duoc su_kien.csv cua ", InpRun, " err=", GetLastError());
      if(InpCloseTerminal)
         TerminalClose(1);
      return;
     }
   string head[];
   string first = FileReadString(h);
   StringReplace(first, ShortToString(0xFEFF), "");
   StringSplit(first, ',', head);
   int cFake = Col(head, "gia"), cType = Col(head, "loai"), cTouch = Col(head, "gio_cham_san"), cDir = Col(head, "chieu");
   int cLevel = Col(head, "muc"), cLo = Col(head, "mep_duoi"), cHi = Col(head, "mep_tren"), cEntry = Col(head, "gia_vao");
   int cB = Col(head, "B"), cFlags = Col(head, "loc"), cK1 = Col(head, "kq1");
   int checked = 0, okRes = 0, okBar = 0, badShown = 0, entryOk = 0;
   while(!FileIsEnding(h) && checked < InpMax)
     {
      string f[];
      if(StringSplit(FileReadString(h), ',', f) < ArraySize(head) - 1)
         continue;
      if(f[cFake] != "0" || (f[cType] != "0" && f[cType] != "1") || (StringToInteger(f[cFlags]) & 256) != 0)
         continue;
      checked++;
      datetime touchClose = StringToTime(f[cTouch]);
      int dir = (int)StringToInteger(f[cDir]);
      double level = StringToDouble(f[cLevel]), lo = StringToDouble(f[cLo]), hi = StringToDouble(f[cHi]);
      double entry = StringToDouble(f[cEntry]), B = StringToDouble(f[cB]);
      // (1) nến chạm: râu vào dải, giá mở ngoài dải đúng phía, đóng qua mức, đúng màu
      MqlRates r[];
      bool barOk = false;
      if(CopyRates(sym, PERIOD_M5, touchClose - 1, 1, r) == 1 && r[0].time == touchClose - 300)
        {
         bool wick = r[0].high >= lo && r[0].low <= hi;
         bool open = dir > 0 ? r[0].open > hi : r[0].open < lo;
         bool conf = dir > 0 ? r[0].close > level && r[0].close > r[0].open : r[0].close < level && r[0].close < r[0].open;
         barOk = wick && open && conf;
        }
      if(barOk)
         okBar++;
      // (2) tick vào = tick đầu tiên của nến sau; giá vào đúng phía
      MqlTick t[];
      long entryMsc = 0;
      if(CopyTicksRange(sym, t, COPY_TICKS_ALL, (ulong)touchClose * 1000, (ulong)(touchClose + 1800) * 1000) > 0)
        {
         entryMsc = t[0].time_msc;
         if(MathAbs((dir > 0 ? t[0].ask : t[0].bid) - entry) < 0.0005)
            entryOk++;
        }
      int res[3];
      Recompute(sym, touchClose, entryMsc, dir, entry, B, res);
      bool same = true;
      for(int k = 0; k < 3; k++)
         same &= res[k] == (int)StringToInteger(f[cK1 + k]);
      if(same)
         okRes++;
      else
         if(badShown < 10)
           {
            badShown++;
            PrintFormat("[LabVerify] LỆCH %s chiều %d vào %.3f B %.3f: Lab %s/%s/%s, tính lại %d/%d/%d", f[cTouch], dir, entry, B,
                        f[cK1], f[cK1 + 1], f[cK1 + 2], res[0], res[1], res[2]);
           }
     }
   FileClose(h);
   PrintFormat("[LabVerify] %s: soát %d sự kiện thật. Nến chạm đúng luật: %d. Giá vào khớp tick đầu nến sau: %d. Kết quả +kB/-1B khớp: %d.",
               InpRun, checked, okBar, entryOk, okRes);
   if(InpCloseTerminal)
      TerminalClose(0);
  }
