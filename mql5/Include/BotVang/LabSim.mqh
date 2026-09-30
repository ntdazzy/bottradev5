// Đo kết quả của từng sự kiện trên tick thật, không đặt lệnh:
// (1) chạm +kB trước hay −1B trước (k = 1, 2, 3) trong 36 nến M5, kèm lời/lỗ tạm lớn nhất theo từng nến;
// (2) lệnh ảo chạy đúng cách quản lý của bot: dừng lỗ 1 bước, thang bậc, khóa lời tại cản, siết trước tin, đóng theo giờ.
#ifndef BOTVANG_LABSIM_MQH
#define BOTVANG_LABSIM_MQH

#include "Signal.mqh"

#define LAB_BARS 36
#define LAB_K 3

// Kết quả phép đo +kB / −1B
#define RES_PENDING -1
#define RES_LOSS 0
#define RES_WIN 1
#define RES_TIMEOUT 2
#define RES_CUT 3          // cửa sổ đo đi qua giờ nghỉ của sàn: không tính

// Lý do đóng lệnh ảo
#define EXIT_NONE 0
#define EXIT_SL 1
#define EXIT_DAYEND 2      // 24:00 VN
#define EXIT_SESSION 3     // 30 phút trước giờ nghỉ của sàn
#define EXIT_MAXBARS 4     // chặn an toàn 288 nến (sự kiện ngoài giờ chạy)
#define EXIT_GAP 5         // dính dừng lỗ ở tick đầu sau giờ nghỉ (giá nhảy)
#define EXIT_UNFINISHED 6  // hết dữ liệu khi chưa đóng

// Loại sự kiện
#define EV_FLIPPED SIG_FLIPPED   // chạm lần đầu vùng vừa lật
#define EV_FRESH SIG_FRESH       // chạm lần đầu vùng còn mới chưa lật
#define EV_REVERSE 2       // đảo chiều tại dừng lỗ của lệnh ảo

// Cờ ứng viên (không thuộc luật gốc; dùng để đo tập con của luật gốc)
#define CF_BSPREAD  1      // B do sàn chênh lệch quyết định
#define CF_CLOSEPOS 2      // vị trí đóng của nến chạm < 0,6
#define CF_CHASE    4      // giá vào đã cách mép vùng > 1,2B
#define CF_WAIT     8      // chạm sau hơn 24 nến kể từ lúc lật
#define CF_LOWVOL   16     // biến động M5 < 0,5 × trung bình 1 ngày
#define CF_BIAS_H1  32     // không cùng hướng H1 (khi chỉ dùng H1)
#define CF_BIAS_H4  64     // không cùng hướng H4 (khi chỉ dùng H4)

// Điều kiện đảo chiều "Có điều kiện" (bit = không đạt)
#define RF_SL_IN_STRONG 1  // giá dừng lỗ nằm trong cản mạnh
#define RF_INSIDE6      2  // nằm trong dải cản quá 6 nến
#define RF_AGAINST      4  // chiều mới ngược hướng lớn và không vừa phá/bị đẩy lại tại vùng mạnh

struct LabEvent
  {
   int               id;
   bool              fake;
   int               type;               // EV_*
   int               src;                // sự kiện đảo: chỉ số sự kiện gốc; khác: -1
   int               zoneId;
   int               parentId;           // vùng giả: id vùng thật đã sinh ra nó
   ENUM_TIMEFRAMES   tf;
   ENUM_ZONE_KIND    kind;
   double            level;
   double            lo;
   double            hi;
   double            zoneAtr;
   datetime          zoneCreated;
   datetime          touchTime;          // giờ đóng nến chạm (= giờ mở nến vào); sự kiện đảo: giờ tick kích hoạt
   int               dir;                // 1 = MUA, -1 = BÁN
   int               scorePre;           // điểm trước nến chạm (vùng thật)
   int               scorePost;          // điểm sau nến chạm
   int               conf;               // số vùng thật cùng vai chồng lên (≤ 0,3 × ATR M15)
   int               bouncesBeforeFlip;
   int               barsFromFlip;
   int               barsFromCreate;
   int               dupCount;           // số vùng khác cho cùng sự kiện (cùng nến, cùng chiều)
   bool              strongOrigin;
   int               round;              // 0 không, 1 chỉ xx50, 2 có xx00
   double            closePos;           // vị trí đóng của nến chạm theo chiều lệnh (0–1)
   double            chaseB;             // giá vào cách mép vùng bao nhiêu B
   int               bias;               // hướng lớn theo chế độ đang chạy
   int               biasRel;            // 1 cùng, -1 ngược, 0 không rõ
   int               session;            // 0 Á, 1 Âu, 2 Mỹ
   int               part;               // 0 = 70a, 1 = 70b, 2 = 30
   int               vnDay;              // yyyymmdd theo giờ VN (khối bootstrap)
   int               vnMinute;
   double            atrM5;
   double            spreadTouch;        // trung vị chênh lệch trong nến chạm
   double            spreadEntry;
   int               flags;              // FL_*
   int               cand;               // CF_*
   int               rev;                // RF_* (chỉ sự kiện đảo)
   bool              overlapReal;        // vùng giả đang chồng lên một vùng thật lúc chạm: không dùng làm đối chứng
   bool              chosen;             // bot sẽ vào (luật gốc, vùng thật)
   bool              busy;               // lúc đó chuỗi lệnh của bot còn lệnh ảo chưa đóng
   // giá vào
   datetime          entryBarOpen;
   long              entryMsc;
   double            entry;
   double            B;
   bool              bBySpread;
   // phép đo +kB / −1B
   int               res[LAB_K];
   int               resBars[LAB_K];
   double            endR;               // lời/lỗ theo B ở tick cuối cửa sổ (dùng cho hết giờ)
   double            lastU;
   datetime          windowEnd;
   bool              measureDone;
   double            mfe[LAB_BARS];      // lời tạm lớn nhất (theo B) từ lúc vào tới hết nến i
   double            mae[LAB_BARS];      // lỗ tạm lớn nhất
   int               curBar;
   double            runMax;
   double            runMin;
   // lệnh ảo
   double            sl;
   double            bNext;              // B cho lệnh đảo: tính lúc dừng lỗ được đặt/dời lần cuối
   datetime          closeAt;
   int               closeReason;
   bool              newsInWin;
   bool              atZone;
   double            oppEdge;            // mép gần của cản mạnh đối diện (0 = không có)
   double            oppLo;
   double            oppHi;
   int               barsInsideOpp;
   int               slMoves;
   bool              simDone;
   double            exitPrice;
   datetime          exitTime;
   int               exitReason;
   double            rGross;             // (thoát − vào) × chiều / B
   double            jumpB;              // phần giá nhảy qua dừng lỗ (theo B, dương = xấu hơn)
  };

void LabEventReset(LabEvent &e)
  {
   ZeroMemory(e);
   e.src = -1;
   for(int k = 0; k < LAB_K; k++)
     {
      e.res[k] = RES_PENDING;
      e.resBars[k] = 0;
     }
  }

class CLabSim
  {
private:
   double            m_tick;
   double            m_minDist;
   int               m_digits;

   double            Norm(double p) const { return m_tick > 0.0 ? NormalizeDouble(MathRound(p / m_tick) * m_tick, m_digits) : p; }

   void              FlushBars(LabEvent &e)
     {
      while(e.curBar < LAB_BARS)
        {
         e.mfe[e.curBar] = e.runMax;
         e.mae[e.curBar] = e.runMin;
         e.curBar++;
        }
     }

   // Phép đo +kB / −1B và lời/lỗ tạm (không dừng khi đã có kết quả, đo đủ 36 nến)
   void              Measure(LabEvent &e, const MqlTick &t, bool gap, double u)
     {
      if(gap)
        {
         for(int k = 0; k < LAB_K; k++)
            if(e.res[k] == RES_PENDING)
               e.res[k] = RES_CUT;
         e.endR = e.lastU;
         FlushBars(e);
         e.measureDone = true;
         return;
        }
      if(t.time >= e.windowEnd)
        {
         for(int k = 0; k < LAB_K; k++)
            if(e.res[k] == RES_PENDING)
              {
               e.res[k] = RES_TIMEOUT;
               e.resBars[k] = LAB_BARS;
              }
         e.endR = e.lastU;
         FlushBars(e);
         e.measureDone = true;
         return;
        }
      int bar = (int)((t.time - e.entryBarOpen) / 300);
      while(e.curBar < bar && e.curBar < LAB_BARS)
        {
         e.mfe[e.curBar] = e.runMax;
         e.mae[e.curBar] = e.runMin;
         e.curBar++;
        }
      e.runMax = MathMax(e.runMax, u);
      e.runMin = MathMin(e.runMin, u);
      e.lastU = u;
      if(t.time_msc <= e.entryMsc)
         return;                     // chỉ xét chạm mốc từ tick sau tick vào
      double move = (e.dir > 0 ? t.bid : t.ask) - e.entry;
      move *= e.dir;
      if(move <= -e.B + 1e-9)
        {
         for(int k = 0; k < LAB_K; k++)
            if(e.res[k] == RES_PENDING)
              {
               e.res[k] = RES_LOSS;
               e.resBars[k] = bar + 1;
              }
         return;
        }
      for(int k = 0; k < LAB_K; k++)
         if(e.res[k] == RES_PENDING && move >= (k + 1) * e.B - 1e-9)
           {
            e.res[k] = RES_WIN;
            e.resBars[k] = bar + 1;
           }
     }

   void              Close(LabEvent &e, double price, datetime at, int reason)
     {
      e.exitPrice = price;
      e.exitTime = at;
      e.exitReason = reason;
      e.rGross = (price - e.entry) * e.dir / e.B;
      e.simDone = true;
     }

   // Lệnh ảo theo cách quản lý của bot. Trả true khi vừa dính dừng lỗ (để sinh sự kiện đảo).
   bool              Manage(LabEvent &e, const MqlTick &t, bool gap, bool newsWin, double bNow)
     {
      double px = e.dir > 0 ? t.bid : t.ask;
      if(t.time_msc > e.entryMsc)
        {
         bool hit = e.dir > 0 ? t.bid <= e.sl : t.ask >= e.sl;
         if(hit)
           {
            // Dính dừng lỗ: thoát đúng mức dừng lỗ; phần giá nhảy qua ghi riêng. Sau giờ nghỉ: thoát ở giá tick đó.
            e.jumpB = (e.sl - px) * e.dir / e.B;
            Close(e, gap ? px : e.sl, t.time, gap ? EXIT_GAP : EXIT_SL);
            return true;
           }
        }
      if(t.time >= e.closeAt)
        {
         Close(e, px, t.time, e.closeReason);
         return false;
        }
      // Tin: siết một lần khi cửa sổ tin bắt đầu (nếu đang lời thì dừng lỗ về giá vào), trong cửa sổ không dời
      if(newsWin)
        {
         if(!e.newsInWin)
           {
            e.newsInWin = true;
            if((px - e.entry) * e.dir > 0.0 && (e.entry - e.sl) * e.dir > 0.0 && (px - e.entry) * e.dir > m_minDist)
              {
               e.sl = Norm(e.entry);
               e.bNext = bNow;
               e.slMoves++;
              }
           }
         return false;
        }
      e.newsInWin = false;
      // Thang bậc: đi thêm n bước thì dừng lỗ nằm sau bậc cao nhất đúng 1 bước
      double target = e.sl;
      int steps = (int)MathFloor((px - e.entry) * e.dir / e.B + 1e-9);
      if(steps >= 1)
        {
         double s = e.entry + e.dir * (steps - 1) * e.B;
         if((s - target) * e.dir > 0.0)
            target = s;
        }
      // Khóa lời tại cản: khoảng cách theo Bid tới mép gần < 1B → dừng lỗ cách giá thoát 0,5B
      e.atZone = false;
      if(e.oppEdge > 0.0)
        {
         double dist = e.dir > 0 ? e.oppEdge - t.bid : t.bid - e.oppEdge;
         if(dist < e.B)
           {
            e.atZone = true;
            double lock = px - e.dir * 0.5 * e.B;
            if((lock - target) * e.dir > 0.0)
               target = lock;
           }
        }
      target = Norm(target);
      if((target - e.sl) * e.dir > 0.0 && (px - target) * e.dir > m_minDist)
        {
         e.sl = target;
         e.bNext = bNow;
         e.slMoves++;
        }
      return false;
     }

public:
   LabEvent          ev[];
   int               n;
   int               active[];
   int               nActive;
   int               hits[];             // chỉ số sự kiện vừa dính dừng lỗ ở tick gần nhất
   int               nHits;

   void              Init(double tickSize, int digits, double minDist)
     {
      m_tick = tickSize;
      m_digits = digits;
      m_minDist = minDist;
      n = 0;
      nActive = 0;
      nHits = 0;
     }

   // Thêm sự kiện. Nếu measure = true thì bắt đầu đo từ tick sau. Trả về chỉ số.
   int               Add(LabEvent &e, bool measure)
     {
      e.id = n;
      if(measure)
        {
         e.windowEnd = e.entryBarOpen + LAB_BARS * 300;
         e.runMax = e.runMin = e.lastU = (((e.dir > 0) ? e.entry - e.spreadEntry : e.entry + e.spreadEntry) - e.entry) * e.dir / e.B;
         e.sl = Norm(e.entry - e.dir * e.B);
         e.bNext = e.B;
        }
      else
        {
         e.measureDone = true;
         e.simDone = true;
         e.exitReason = EXIT_NONE;
        }
      ArrayResize(ev, n + 1, 1024);
      ev[n] = e;
      if(measure)
        {
         ArrayResize(active, nActive + 1, 64);
         active[nActive++] = n;
        }
      return n++;
     }

   // Cập nhật mọi sự kiện đang đo bằng một tick. Sau lời gọi, hits[] chứa các sự kiện vừa dính dừng lỗ.
   void              OnTick(const MqlTick &t, bool gap, bool newsWin, double atrM5, double stepMult, double spreadMult)
     {
      nHits = 0;
      double bNow = MathMax(stepMult * atrM5, spreadMult * (t.ask - t.bid));
      int keep = 0;
      for(int a = 0; a < nActive; a++)
        {
         int i = active[a];
         double px = ev[i].dir > 0 ? t.bid : t.ask;
         double u = (px - ev[i].entry) * ev[i].dir / ev[i].B;
         if(!ev[i].measureDone)
            Measure(ev[i], t, gap, u);
         if(!ev[i].simDone && Manage(ev[i], t, gap, newsWin, Norm(bNow)))
           {
            ArrayResize(hits, nHits + 1, 16);
            hits[nHits++] = i;
           }
         if(!ev[i].measureDone || !ev[i].simDone)
            active[keep++] = i;
        }
      nActive = keep;
     }

   // Hết dữ liệu: đóng mọi thứ còn dở (không tính vào thống kê)
   void              Finish(const MqlTick &t)
     {
      for(int a = 0; a < nActive; a++)
        {
         int i = active[a];
         if(!ev[i].measureDone)
           {
            for(int k = 0; k < LAB_K; k++)
               if(ev[i].res[k] == RES_PENDING)
                  ev[i].res[k] = RES_CUT;
            FlushBars(ev[i]);
            ev[i].measureDone = true;
           }
         if(!ev[i].simDone)
            Close(ev[i], ev[i].dir > 0 ? t.bid : t.ask, t.time, EXIT_UNFINISHED);
        }
      nActive = 0;
     }
  };

#endif
