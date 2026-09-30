// Nhật ký từng lệnh của BotFvgNhanChim: mỗi lệnh đã đóng một dòng CSV (dấu ;) trong Common\Files\BotFvgNhanChim\.
// File đang bị chương trình khác khóa (ví dụ đang mở bằng Excel) thì giữ dòng lại và ghi ở lần sau.
#ifndef BOTVANG_FVGNCJOURNAL_MQH
#define BOTVANG_FVGNCJOURNAL_MQH

#include "FvgNcBook.mqh"

class CFvgJournal
  {
private:
   string            m_file;
   int               m_digits;
   string            m_queue[];
   bool              m_warned;

   string            Price(double p) const { return p > 0.0 ? DoubleToString(p, m_digits) : ""; }
   static string     Time(datetime t, int mode) { return t > 0 ? TimeToString(t, mode) : ""; }

public:
   int               rows;   // số dòng đã ghi

   void              Init(const string file, bool fresh, int digits)
     {
      m_file = file;
      m_digits = digits;
      m_warned = false;
      rows = 0;
      ArrayResize(m_queue, 0);
      if(fresh)
         FileDelete(file, FILE_COMMON);
     }

   static string     ReasonText(int r)
     {
      switch(r)
        {
         case FX_TP:    return "chot loi";
         case FX_SL:    return "dung lo";
         case FX_TIME:  return "giu du 500 nen";
         case FX_END:   return "con mo luc het du lieu";
         case FX_LIMIT: return "gioi han lo";
         case FX_SO:    return "san cat lenh (thieu ky quy)";
        }
      return "dong tay / khac";
     }

   // Một lệnh đã đóng. R = (giá đóng − giá khớp) × chiều ÷ |giá khớp − dừng lỗ lúc vào|, chưa trừ phí (như cột R0 của PhanUngLab)
   void              Trade(const FvgTrade &x, const FvgExit &e)
     {
      double risk = MathAbs(x.fill - x.sl);
      string r = e.known && risk > 0.0 ? DoubleToString((e.price - x.fill) * x.dir / risk, 3) : "";
      string line = StringFormat("%I64d;%s;%d;%s;%s;%d;%s;%s;%s;%s;%s;%s;%s;%d;%s;%s;%s\r\n", x.id, Time(x.sig, TIME_DATE | TIME_MINUTES),
                                 x.dir, Price(x.zTop), Price(x.zBot), x.zones, Price(x.want), Price(x.sl), Price(x.tp),
                                 Time(x.fillTime, TIME_DATE | TIME_SECONDS), Price(x.fill), Time(e.time, TIME_DATE | TIME_SECONDS),
                                 e.known ? Price(e.price) : "", e.known ? e.reason : 0, e.known ? ReasonText(e.reason) : "khong doc duoc lich su",
                                 r, e.known ? DoubleToString(e.money, 2) : "");
      int k = ArraySize(m_queue);
      ArrayResize(m_queue, k + 1, 16);
      m_queue[k] = line;
      Flush();
     }

   void              Flush(void)
     {
      int k = ArraySize(m_queue);
      if(k == 0)
         return;
      int h = FileOpen(m_file, FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_SHARE_READ, 0, CP_UTF8);
      if(h == INVALID_HANDLE)
        {
         if(!m_warned)
            PrintFormat("[BotFvgNhanChim] loi_ghi_nhat_ky | Không mở được %s (err %d, file đang bị khóa?): giữ %d dòng, ghi lại sau",
                        m_file, GetLastError(), k);
         m_warned = true;
         return;
        }
      if(FileSize(h) == 0)
        {
         FileWriteString(h, "# BotFvgNhanChim (SPEC §23): moi lenh da dong mot dong; gio san (gio VN = gio san + 7); nen_tin_hieu = gio mo nen nhan chim; "
                         "gia_gui = Ask (mua) / Bid (ban) luc gui lenh; ly_do: 1 chot loi, 2 dung lo, 3 giu du 500 nen, 4 con mo luc het du lieu, "
                         "5 gioi han lo, 6 dong tay/khac, 7 san cat lenh; R chua tru phi = (gia_dong - gia_khop) x chieu / |gia_khop - sl|; tien = loi/lo + phi\r\n");
         FileWriteString(h, "ma_lenh;nen_tin_hieu;chieu;vung_tren;vung_duoi;so_vung;gia_gui;sl;tp;khop_luc;gia_khop;dong_luc;gia_dong;ly_do;ly_do_chu;R;tien\r\n");
        }
      FileSeek(h, 0, SEEK_END);
      for(int i = 0; i < k; i++)
         FileWriteString(h, m_queue[i]);
      FileClose(h);
      rows += k;
      m_warned = false;
      ArrayResize(m_queue, 0);
     }
  };

#endif
