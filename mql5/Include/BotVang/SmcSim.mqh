// Lệnh ảo của SmcLab (SPEC §21.1, §21.3): lệnh giới hạn hoặc vào ngay, khớp theo tick đúng phía, dừng lỗ/chốt lời, hủy theo luật.
// Để chạy nhanh trên hàng chục triệu tick: chỉ duyệt các lệnh khi giá chạm một ngưỡng nào đó (giữ 4 ngưỡng gần nhất).
#ifndef BOTVANG_SMCSIM_MQH
#define BOTVANG_SMCSIM_MQH

#define VK_REAL 0   // lệnh thật của cách vào lệnh
#define VK_RCL  1   // đối chứng mức ngẫu nhiên
#define VK_RCT  2   // đối chứng thời điểm ngẫu nhiên
#define VK_RCD  3   // đối chứng đảo chiều

#define VS_PENDING 0
#define VS_OPEN    1
#define VS_DONE    2

#define VX_NONE        0
#define VX_TP          1
#define VX_SL          2
#define VX_TIME        3   // giữ quá số nến tối đa: đóng theo giá thị trường
#define VX_END         4   // hết dữ liệu khi còn mở (không tính)
#define VX_C_BARS      5   // hủy: quá số nến chờ
#define VX_C_INVALID   6   // hủy: nến đóng qua mép xa của vùng
#define VX_C_TPFIRST   7   // hủy: giá chạy tới mức chốt lời trước khi khớp
#define VX_C_OPP       8   // hủy: phá cấu trúc ngược chiều cùng lớp
#define VX_C_END       9   // hết dữ liệu khi chưa khớp

struct VOrder
  {
   int               cell;
   int               kind;
   int               arm;        // mã lần "đặt" của lệnh thật (đối chứng dùng chung mã để ghép cặp)
   int               dir;
   bool              market;     // vào ngay theo giá thị trường
   double            entry, sl, tp;
   double            zoneEdge;   // hủy khi nến đóng qua mức này (mua: đóng < zoneEdge)
   int               layer;      // lớp cấu trúc để hủy khi phá ngược chiều (−1: không áp)
   int               maxBars;    // số nến chờ tối đa (0: không giới hạn)
   bool              tpFirst;
   datetime          armTime;
   int               armBar;
   int               state;
   datetime          fillTime;
   double            fill;
   int               fillBar;
   datetime          exitTime;
   double            exit;
   int               reason;
   int               legs;       // số chặng đi theo giá thị trường/lệnh dừng (để trừ đệm trượt)
   bool              flipDone;   // lệnh thật đã sinh đối chứng đảo chiều
  };

class CSmcSim
  {
private:
   int               m_act[];
   int               m_nAct;
   double            m_upBid, m_upAsk, m_loBid, m_loAsk;

   void              Widen(void) { m_upBid = DBL_MAX; m_upAsk = DBL_MAX; m_loBid = -DBL_MAX; m_loAsk = -DBL_MAX; }

   void              Thresholds(const VOrder &v)
     {
      if(v.state == VS_PENDING)
        {
         if(v.dir > 0)
           {
            m_loAsk = MathMax(m_loAsk, v.entry);
            if(v.tpFirst)
               m_upBid = MathMin(m_upBid, v.tp);
           }
         else
           {
            m_upBid = MathMin(m_upBid, v.entry);
            if(v.tpFirst)
               m_loAsk = MathMax(m_loAsk, v.tp);
           }
        }
      else
         if(v.state == VS_OPEN)
           {
            if(v.dir > 0)
              {
               m_loBid = MathMax(m_loBid, v.sl);
               m_upBid = MathMin(m_upBid, v.tp);
              }
            else
              {
               m_upAsk = MathMin(m_upAsk, v.sl);
               m_loAsk = MathMax(m_loAsk, v.tp);
              }
           }
     }

   void              Rebuild(void)
     {
      Widen();
      int keep = 0;
      for(int k = 0; k < m_nAct; k++)
         if(o[m_act[k]].state != VS_DONE)
           {
            m_act[keep++] = m_act[k];
            Thresholds(o[m_act[k]]);
           }
      m_nAct = keep;
     }

   void              Close(VOrder &v, datetime t, double price, int reason, bool marketLeg)
     {
      v.state = VS_DONE;
      v.exitTime = t;
      v.exit = price;
      v.reason = reason;
      if(marketLeg)
         v.legs++;
     }

   void              Cancel(VOrder &v, datetime t, int reason)
     {
      v.state = VS_DONE;
      v.exitTime = t;
      v.reason = reason;
     }

   void              Fill(int idx, datetime t, double price, int bar)
     {
      o[idx].state = VS_OPEN;
      o[idx].fillTime = t;
      o[idx].fill = price;
      o[idx].fillBar = bar;
      if(o[idx].kind == VK_REAL)
        {
         ArrayResize(justFilled, nJust + 1, 256);
         justFilled[nJust++] = idx;
        }
     }

   // Xét lệnh idx với tick t
   void              Step(int idx, const MqlTick &t, int bar)
     {
      VOrder v = o[idx];
      if(v.state == VS_PENDING)
        {
         if(v.dir > 0)
           {
            if(v.tpFirst && t.bid >= v.tp)
              {
               Cancel(v, t.time, VX_C_TPFIRST);
               o[idx] = v;
               return;
              }
            if(t.ask <= v.entry)
              {
               Fill(idx, t.time, MathMin(v.entry, t.ask), bar);   // giá nhảy qua mức đặt: khớp ở giá tốt hơn
               v = o[idx];
              }
           }
         else
           {
            if(v.tpFirst && t.ask <= v.tp)
              {
               Cancel(v, t.time, VX_C_TPFIRST);
               o[idx] = v;
               return;
              }
            if(t.bid >= v.entry)
              {
               Fill(idx, t.time, MathMax(v.entry, t.bid), bar);
               v = o[idx];
              }
           }
        }
      if(v.state == VS_OPEN)
        {
         if(v.dir > 0)
           {
            if(t.bid <= v.sl)
               Close(v, t.time, t.bid, VX_SL, true);
            else
               if(t.bid >= v.tp)
                  Close(v, t.time, v.tp, VX_TP, false);
           }
         else
           {
            if(t.ask >= v.sl)
               Close(v, t.time, t.ask, VX_SL, true);
            else
               if(t.ask <= v.tp)
                  Close(v, t.time, v.tp, VX_TP, false);
           }
        }
      o[idx] = v;
     }

public:
   VOrder            o[];
   int               n;
   int               curBar;
   int               justFilled[];   // lệnh thật vừa khớp (để sinh đối chứng đảo chiều), người gọi xóa sau khi dùng
   int               nJust;

   void              Init(void)
     {
      n = 0;
      m_nAct = 0;
      curBar = 0;
      nJust = 0;
      ArrayResize(o, 0, 65536);
      ArrayResize(m_act, 0, 4096);
      Widen();
     }

   // Thêm lệnh; lệnh vào ngay thì khớp luôn theo tick hiện tại. Trả về chỉ số lệnh.
   int               Add(VOrder &v, const MqlTick &t)
     {
      v.state = VS_PENDING;
      v.reason = VX_NONE;
      v.legs = 0;
      v.flipDone = false;
      v.armTime = t.time;
      v.armBar = curBar;
      ArrayResize(o, n + 1, 65536);
      o[n] = v;
      if(v.market)
        {
         Fill(n, t.time, v.dir > 0 ? t.ask : t.bid, curBar);
         o[n].legs = 1;
        }
      ArrayResize(m_act, m_nAct + 1, 4096);
      m_act[m_nAct++] = n;
      Thresholds(o[n]);
      n++;
      return n - 1;
     }

   void              OnTick(const MqlTick &t)
     {
      if(t.bid < m_upBid && t.ask < m_upAsk && t.bid > m_loBid && t.ask > m_loAsk)
         return;
      for(int k = 0; k < m_nAct; k++)
         Step(m_act[k], t, curBar);
      Rebuild();
     }

   // Nến vừa đóng (chỉ số bar, giá đóng close): hủy lệnh chờ theo luật; opp[layer] = chiều phá cấu trúc ở nến này (0: không).
   // Lệnh mở quá maxHold nến thì đóng theo tick t (tick đầu của nến mới).
   void              OnBar(int bar, double close, const int &opp[], int maxHold, const MqlTick &t)
     {
      for(int k = 0; k < m_nAct; k++)
        {
         VOrder v = o[m_act[k]];
         if(v.state == VS_PENDING)
           {
            if(v.maxBars > 0 && bar - v.armBar >= v.maxBars)
               Cancel(v, t.time, VX_C_BARS);
            else
               if((v.dir > 0 && close < v.zoneEdge) || (v.dir < 0 && close > v.zoneEdge))
                  Cancel(v, t.time, VX_C_INVALID);
               else
                  if(v.layer >= 0 && opp[v.layer] == -v.dir)
                     Cancel(v, t.time, VX_C_OPP);
           }
         else
            if(v.state == VS_OPEN && bar - v.fillBar >= maxHold)
               Close(v, t.time, v.dir > 0 ? t.bid : t.ask, VX_TIME, true);
         o[m_act[k]] = v;
        }
      Rebuild();
     }

   void              Finish(const MqlTick &t)
     {
      for(int k = 0; k < m_nAct; k++)
        {
         VOrder v = o[m_act[k]];
         if(v.state == VS_PENDING)
            Cancel(v, t.time, VX_C_END);
         else
            if(v.state == VS_OPEN)
               Close(v, t.time, v.dir > 0 ? t.bid : t.ask, VX_END, false);
         o[m_act[k]] = v;
        }
      Rebuild();
     }

   // R của một lệnh đã đóng (theo giá khớp thật) sau khi trừ đệm trượt c (theo giá) cho mỗi chặng thị trường/lệnh dừng,
   // chia cho khoảng dừng lỗ dự kiến |giá đặt − SL| (lệnh vào ngay: giá đặt = giá khớp)
   static double     R(const VOrder &v, double c)
     {
      double risk = MathAbs(v.entry - v.sl);
      if(risk <= 0.0)
         return 0.0;
      return ((v.exit - v.fill) * v.dir - c * v.legs) / risk;
     }
  };

#endif
