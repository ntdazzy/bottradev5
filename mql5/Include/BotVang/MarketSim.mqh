// Lệnh ảo vào ngay theo giá thị trường của PhanUngLab (SPEC §21.1, §22.3). Cùng quy ước với CSmcSim (SmcSim.mqh): khớp giá Ask (mua)
// / Bid (bán) ở tick vào; dừng lỗ theo tick đúng phía (mua: Bid ≤ SL, bán: Ask ≥ SL), đóng ở giá tick đó và tính một chặng đệm trượt;
// chốt lời đóng đúng giá TP; giữ quá N nến thì đóng theo giá thị trường (một chặng); hết dữ liệu khi còn mở thì không tính.
// Chỉ có lệnh vào ngay, và mỗi tick chỉ xem ngưỡng gần giá nhất trong 4 hàng đợi, nên chạy được vài triệu lệnh ảo trên tick thật.
// SPEC §24 bản (b): một lần vào gồm 2 nửa cùng giá vào và SL (AddPair); nửa A chốt lời thì SL của nửa B dời về giá vào ngay.
#ifndef BOTVANG_MARKETSIM_MQH
#define BOTVANG_MARKETSIM_MQH

#include "MinHeap.mqh"

#define MK_REAL 0   // lệnh thật
#define MK_RCT  2   // đối chứng thời điểm ngẫu nhiên
#define MK_RCD  3   // đối chứng đảo chiều
#define MK_X1   4   // nhóm X1: cùng mẫu nến nhưng ngoài vùng
#define MK_X2   5   // nhóm X2: chạm vùng là vào

#define MX_OPEN 0   // đang mở
#define MX_TP   1
#define MX_SL   2
#define MX_TIME 3   // giữ quá số nến tối đa: đóng theo giá thị trường
#define MX_END  4   // hết dữ liệu khi còn mở (không tính)

struct MOrder
  {
   int               arm;       // mã lần vào: lệnh thật và đối chứng của nó dùng chung; X1/X2: mã trong nhóm
   int               cell;
   char              kind;
   char              dir;
   char              legs;      // số chặng theo giá thị trường/lệnh dừng (mỗi chặng trừ một lần đệm trượt)
   char              reason;
   char              half;      // 0 lệnh đơn; 1 nửa A (chốt ở TP1); 2 nửa B (ăn thêm), luôn ở chỉ số nửa A + 1
   char              be;        // nửa B: 1 khi SL đã dời về giá vào (lúc nửa A chốt lời); sl vẫn giữ SL ban đầu
   int               fillBar;   // chỉ số nến đã đóng cuối cùng lúc vào
   datetime          fillTime;
   datetime          exitTime;
   double            fill, sl, tp, exit;
  };

class CMarketSim
  {
private:
   CMinHeap          m_buySl, m_buyTp, m_sellSl, m_sellTp;   // khóa −SL, TP, SL, −TP: ngưỡng gần giá nhất ở đầu hàng
   int               m_head;   // lệnh cũ nhất có thể còn mở (lệnh thêm theo thời gian nên fillBar không giảm theo chỉ số)

   void              Close(int k, datetime t, double price, int reason, bool marketLeg)
     {
      o[k].reason = (char)reason;
      o[k].exitTime = t;
      o[k].exit = price;
      if(marketLeg)
         o[k].legs++;
     }

   // Chốt lời lệnh k; nếu là nửa A thì nửa B còn mở dời SL về giá vào (thêm mục mới vào hàng đợi SL, mục cũ bị bỏ khi tới lượt)
   void              TakeProfit(int k, datetime t)
     {
      Close(k, t, o[k].tp, MX_TP, false);
      if(o[k].half != 1 || o[k + 1].reason != MX_OPEN)
         return;
      int b = k + 1;
      o[b].be = 1;
      if(o[b].dir > 0)
         m_buySl.Push(-o[b].fill, b);
      else
         m_sellSl.Push(o[b].fill, b);
     }

public:
   MOrder            o[];
   int               n;
   int               curBar;

   void              Init(void)
     {
      n = 0;
      m_head = 0;
      curBar = 0;
      ArrayResize(o, 0);
      m_buySl.Init();
      m_buyTp.Init();
      m_sellSl.Init();
      m_sellTp.Init();
     }

   // Vào ngay ở tick t (mua giá Ask, bán giá Bid). Trả về chỉ số lệnh.
   int               Add(int kind, int cell, int arm, int dir, double sl, double tp, const MqlTick &t)
     {
      if(n >= ArraySize(o))
         ArrayResize(o, 2 * n + 65536);
      o[n].arm = arm;
      o[n].cell = cell;
      o[n].kind = (char)kind;
      o[n].dir = (char)dir;
      o[n].legs = 1;
      o[n].reason = MX_OPEN;
      o[n].half = 0;
      o[n].be = 0;
      o[n].fillBar = curBar;
      o[n].fillTime = t.time;
      o[n].exitTime = 0;
      o[n].fill = dir > 0 ? t.ask : t.bid;
      o[n].sl = sl;
      o[n].tp = tp;
      o[n].exit = 0.0;
      if(dir > 0)
        {
         m_buySl.Push(-sl, n);
         m_buyTp.Push(tp, n);
        }
      else
        {
         m_sellSl.Push(sl, n);
         m_sellTp.Push(-tp, n);
        }
      return n++;
     }

   // SPEC §24 bản (b): vào 2 nửa ở tick t, cùng giá vào và SL; nửa A chốt ở tp, nửa B (chỉ số A + 1) ở tp2. Trả về chỉ số nửa A.
   int               AddPair(int kind, int cell, int arm, int dir, double sl, double tp, double tp2, const MqlTick &t)
     {
      int a = Add(kind, cell, arm, dir, sl, tp, t);
      Add(kind, cell, arm, dir, sl, tp2, t);
      o[a].half = 1;
      o[a + 1].half = 2;
      return a;
     }

   // SL đang dùng của lệnh: nửa B đã dời về hòa vốn thì là giá vào
   static double     CurSl(const MOrder &v) { return v.be != 0 ? v.fill : v.sl; }

   // Dừng lỗ / chốt lời theo tick. Mục trong hàng đợi của lệnh đã đóng (bởi ngưỡng kia), hoặc mục SL cũ của nửa B đã dời về
   // hòa vốn, bị bỏ qua khi tới lượt.
   void              OnTick(const MqlTick &t)
     {
      while(m_buySl.n > 0 && -t.bid >= m_buySl.TopKey())
        {
         double key = m_buySl.TopKey();
         int k = m_buySl.TopId();
         m_buySl.Pop();
         if(o[k].reason == MX_OPEN && -CurSl(o[k]) == key)
            Close(k, t.time, t.bid, MX_SL, true);
        }
      while(m_buyTp.n > 0 && t.bid >= m_buyTp.TopKey())
        {
         int k = m_buyTp.TopId();
         m_buyTp.Pop();
         if(o[k].reason == MX_OPEN)
            TakeProfit(k, t.time);
        }
      while(m_sellSl.n > 0 && t.ask >= m_sellSl.TopKey())
        {
         double key = m_sellSl.TopKey();
         int k = m_sellSl.TopId();
         m_sellSl.Pop();
         if(o[k].reason == MX_OPEN && CurSl(o[k]) == key)
            Close(k, t.time, t.ask, MX_SL, true);
        }
      while(m_sellTp.n > 0 && -t.ask >= m_sellTp.TopKey())
        {
         int k = m_sellTp.TopId();
         m_sellTp.Pop();
         if(o[k].reason == MX_OPEN)
            TakeProfit(k, t.time);
        }
     }

   // Nến bar vừa đóng: lệnh mở từ maxHold nến trở lên thì đóng theo tick t (tick đầu của nến mới)
   void              OnBar(int bar, int maxHold, const MqlTick &t)
     {
      while(m_head < n && bar - o[m_head].fillBar >= maxHold)
        {
         if(o[m_head].reason == MX_OPEN)
            Close(m_head, t.time, o[m_head].dir > 0 ? t.bid : t.ask, MX_TIME, true);
         m_head++;
        }
     }

   void              Finish(const MqlTick &t)
     {
      for(int k = m_head; k < n; k++)
         if(o[k].reason == MX_OPEN)
            Close(k, t.time, o[k].dir > 0 ? t.bid : t.ask, MX_END, false);
     }

   // Kết quả theo giá của lệnh đã đóng sau khi trừ đệm trượt c cho mỗi chặng (vàng: = USD cho 0,01 lot)
   static double     Price(const MOrder &v, double c) { return (v.exit - v.fill) * v.dir - c * v.legs; }

   // R của lệnh đã đóng sau khi trừ đệm trượt c (theo giá) cho mỗi chặng, chia cho khoảng dừng lỗ dự kiến |giá vào − SL|
   static double     R(const MOrder &v, double c)
     {
      double risk = MathAbs(v.fill - v.sl);
      if(risk <= 0.0)
         return 0.0;
      return ((v.exit - v.fill) * v.dir - c * v.legs) / risk;
     }
  };

#endif
