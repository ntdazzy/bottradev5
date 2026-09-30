// Tín hiệu vào lệnh dùng chung cho BotVangLab và bot BotVang,
// để bot vào lệnh đúng như những gì Lab đã đo.
#ifndef BOTVANG_SIGNAL_MQH
#define BOTVANG_SIGNAL_MQH

#include "Zones.mqh"
#include "Filters.mqh"

#define SIG_FLIPPED 0     // chạm lần đầu vùng vừa lật (luật gốc)
#define SIG_FRESH 1       // chạm lần đầu vùng còn mới chưa lật

// Lý do bị lọc (tầng 2). Luật gốc = không có bit nào.
#define FL_BIAS     1      // không cùng hướng lớn
#define FL_SCORE    2      // điểm < 4 (chỉ vùng thật)
#define FL_ROOM     4      // khoảng tới cản mạnh đối diện < 2B
#define FL_TIME     8      // ngoài giờ chạy
#define FL_SESSION  16     // sàn nghỉ / sắp nghỉ / vừa mở lại
#define FL_SPREAD   32     // chênh lệch > 0,50
#define FL_NEWS     64     // trong cửa sổ tin
#define FL_NONEWS   128    // bật lọc tin nhưng không có lịch tin
#define FL_NOENTRY  256    // không có giá vào trong 30 phút sau nến chạm

struct SignalPick
  {
   Zone              z;
   int               type;   // SIG_*
   int               dir;    // 1 = MUA, -1 = BÁN
   int               dup;    // số vùng khác cho cùng (loại, chiều) ở nến này
  };

// Cài đặt bộ lọc thị trường
struct MarketCfg
  {
   bool              timeFilter;
   int               vnOffset;
   int               startMin;
   int               endMin;
   int               breakCloseMin;
   int               afterOpenMin;
   double            maxSpread;
   bool              newsFilter;
   bool              newsRequired;     // true: bật lọc tin mà không có lịch tin thì không vào (chạy thật); tester thiếu file thì bỏ qua lọc tin
   bool              specIsSummer;     // tester: lịch phiên trong terminal đang theo giờ hè Mỹ → ngày mùa đông dời lịch 1 giờ
  };

// Dời lịch phiên (giây) khi chạy lại dữ liệu cũ: sàn nghỉ 20:58–22:00 giờ sàn vào giờ hè Mỹ, 21:58–23:00 vào giờ đông
int SessionShift(const MarketCfg &c, datetime t) { return c.specIsSummer && !UsDst(t) ? 3600 : 0; }

bool SessionAt(const MarketCfg &c, const string sym, datetime t, int &toEnd, int &fromStart)
  {
   return SessionInfo(sym, t - SessionShift(c, t), toEnd, fromStart);
  }

int TfRank(ENUM_TIMEFRAMES tf) { return tf == PERIOD_M15 ? 0 : (tf == PERIOD_H1 ? 1 : (tf == PERIOD_D1 ? 2 : 3)); }

// Vùng bot chọn khi nhiều vùng cùng cho một sự kiện: điểm cao hơn, rồi khung lớn hơn, rồi vùng cũ hơn
bool BetterZone(const Zone &a, const Zone &b)
  {
   if(a.score != b.score)
      return a.score > b.score;
   if(TfRank(a.tf) != TfRank(b.tf))
      return TfRank(a.tf) > TfRank(b.tf);
   return a.created < b.created;
  }

// điều 3: nến chạm đóng qua mức và đúng màu
bool SignalConfirmed(const Zone &z, int dir, const MqlRates &bar)
  {
   return dir > 0 ? bar.close > z.level && bar.close > bar.open : bar.close < z.level && bar.close < bar.open;
  }

// Gom các lần chạm đầu đã xác nhận ở nến vừa đóng: mỗi (loại, chiều) một tín hiệu, gán cho vùng bot sẽ chọn.
// Trả về số tín hiệu (tối đa 4); unconfirmed = số lần chạm đầu không có nến xác nhận.
int PickSignals(const Zone &evz[], const int &evf[], int cnt, const MqlRates &bar, SignalPick &out[], int &unconfirmed)
  {
   int best[2][2];
   int dup[2][2];
   ArrayInitialize(best, -1);
   ArrayInitialize(dup, 0);
   unconfirmed = 0;
   for(int i = 0; i < cnt; i++)
     {
      if((evf[i] & ZEV_FIRST_TOUCH) == 0 || evz[i].flipFailed)
         continue;
      int type = evz[i].flips == 1 ? SIG_FLIPPED : SIG_FRESH;
      int dir = evz[i].isRes ? -1 : 1;
      if(!SignalConfirmed(evz[i], dir, bar))
        {
         unconfirmed++;
         continue;
        }
      int d = dir > 0 ? 0 : 1;
      dup[type][d]++;
      if(best[type][d] < 0 || BetterZone(evz[i], evz[best[type][d]]))
         best[type][d] = i;
     }
   int n = 0;
   ArrayResize(out, 4);
   for(int type = 0; type < 2; type++)
      for(int d = 0; d < 2; d++)
         if(best[type][d] >= 0)
           {
            out[n].z = evz[best[type][d]];
            out[n].type = type;
            out[n].dir = d == 0 ? 1 : -1;
            out[n].dup = dup[type][d] - 1;
            n++;
           }
   ArrayResize(out, n);
   return n;
  }

// Bước B = max(x × ATR(M5) nến vừa đóng, y × chênh lệch lúc vào), làm tròn theo bước giá
double StepB(double atrM5, double spread, double atrMult, double spreadMult, double tickSize, int digits, bool &bySpread)
  {
   double a = atrMult * atrM5, s = spreadMult * spread;
   bySpread = s > a;
   return NormalizeDouble(MathRound(MathMax(a, s) / tickSize) * tickSize, digits);
  }

// điều 4: khoảng lời thực tới mép gần của cản mạnh đối diện (đo bằng Bid, trừ chênh lệch) còn >= minRoomB × B
bool RoomOk(CZones &zones, int dir, double bid, double spread, double B, int strongScore, double minRoomB)
  {
   double dist;
   return zones.NearestStrong(dir, bid, strongScore, dist) < 0 || dist - spread >= minRoomB * B;
  }

// Lý do bị lọc theo thị trường tại thời điểm at
int MarketFlags(const MarketCfg &c, const string sym, datetime at, double spread, bool newsAvailable, bool newsWin)
  {
   int f = 0;
   if(c.timeFilter && !InTimeWindow(at, c.vnOffset, c.startMin, c.endMin))
      f |= FL_TIME;
   int toEnd, fromStart;
   if(!SessionAt(c, sym, at, toEnd, fromStart) || toEnd <= c.breakCloseMin || fromStart < c.afterOpenMin)
      f |= FL_SESSION;
   if(spread > c.maxSpread)
      f |= FL_SPREAD;
   if(c.newsFilter)
     {
      if(!newsAvailable)
        {
         if(c.newsRequired)
            f |= FL_NONEWS;
        }
      else
         if(newsWin)
            f |= FL_NEWS;
     }
   return f;
  }

string FlagText(int f)
  {
   string s = "";
   if((f & FL_BIAS) != 0)
      s += "ngược/không rõ hướng lớn; ";
   if((f & FL_SCORE) != 0)
      s += "điểm vùng thấp; ";
   if((f & FL_ROOM) != 0)
      s += "cản mạnh phía trước quá gần; ";
   if((f & FL_TIME) != 0)
      s += "ngoài giờ chạy; ";
   if((f & FL_SESSION) != 0)
      s += "sàn sắp nghỉ/vừa mở; ";
   if((f & FL_SPREAD) != 0)
      s += "chênh lệch giãn; ";
   if((f & FL_NEWS) != 0)
      s += "gần giờ tin mạnh; ";
   if((f & FL_NONEWS) != 0)
      s += "không có dữ liệu tin; ";
   if((f & FL_NOENTRY) != 0)
      s += "không có giá vào kịp; ";
   return s;
  }

#endif
