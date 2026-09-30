// Tìm các đối tượng SMC trên nến đã đóng: ATR Wilder, đỉnh/đáy pivot N/N, BOS/CHoCH (2 lớp), OB, FVG,
// mức thanh khoản và cú quét. Mọi đối tượng chỉ dùng được từ sau lúc đóng nến xác nhận nó (không nhìn trước).
#ifndef BOTVANG_SMCDETECT_MQH
#define BOTVANG_SMCDETECT_MQH

struct SmcBar
  {
   datetime          t;
   double            o, h, l, c;
   double            atr;       // ATR(14) Wilder tính tới hết nến này
   bool              jump;      // nến nhảy giá: |mở − đóng nến trước| > 0,5 ATR
  };

// Dãy nến đã đóng, chỉ số tuyệt đối từ 0; ATR Wilder: hạt giống = trung bình 14 biên độ thật đầu
class CSmcBars
  {
private:
   double            m_sum;
   int               m_cnt;
public:
   SmcBar            b[];
   int               n;

   void              Init(void) { n = 0; m_sum = 0.0; m_cnt = 0; ArrayResize(b, 0, 8192); }
   bool              Ready(void) const { return m_cnt >= 14; }

   int               Add(const MqlRates &r)
     {
      double tr = r.high - r.low;
      if(n > 0)
         tr = MathMax(tr, MathMax(MathAbs(r.high - b[n - 1].c), MathAbs(r.low - b[n - 1].c)));
      double atr;
      if(m_cnt < 14)
        {
         m_sum += tr;
         m_cnt++;
         atr = m_sum / m_cnt;
        }
      else
         atr = (b[n - 1].atr * 13.0 + tr) / 14.0;
      ArrayResize(b, n + 1, 8192);
      b[n].t = r.time;
      b[n].o = r.open;
      b[n].h = r.high;
      b[n].l = r.low;
      b[n].c = r.close;
      b[n].atr = atr;
      b[n].jump = n > 0 && MathAbs(r.open - b[n - 1].c) > 0.5 * b[n - 1].atr;
      n++;
      return n - 1;
     }
  };

// Một lần phá cấu trúc (BOS/CHoCH) và OB đi kèm
struct SmcBreak
  {
   bool              valid;
   int               dir;       // +1 phá lên, −1 phá xuống
   bool              choch;
   bool              initial;   // lần phá đầu, chưa có xu hướng: không tính thống kê
   int               i;         // nến phá
   int               pivot;     // nến đỉnh/đáy bị phá
   int               leg;       // nến cực trị của chân (đáy thấp nhất giữa đỉnh và nến phá, khi phá lên)
   bool              ob;        // có OB hợp lệ
   double            obLo, obHi;
  };

// Cấu trúc một lớp: pivot N/N, zigzag (đỉnh cùng loại liền nhau giữ cái cực trị hơn), phá bằng giá đóng
class CSmcStructure
  {
private:
   int               m_n;
   int               m_last;           // loại swing cuối trong zigzag: 1 đỉnh, −1 đáy, 0 chưa có
   bool              m_hOk, m_hBroken;
   int               m_hIdx;
   double            m_hPrice;
   bool              m_lOk, m_lBroken;
   int               m_lIdx;
   double            m_lPrice;
   double            m_highs[], m_lows[];   // giá các đỉnh/đáy đã xác nhận theo zigzag, cũ → mới (giữ 500 cái gần nhất)

   // Ghi giá đỉnh/đáy: replace = đỉnh liền đỉnh cao hơn (đáy liền đáy thấp hơn) thay cho cái cuối
   static void       Record(double &a[], double price, bool replace)
     {
      int k = ArraySize(a);
      if(replace && k > 0)
        {
         a[k - 1] = price;
         return;
        }
      if(k >= 500)
        {
         ArrayRemove(a, 0, 1);
         k--;
        }
      ArrayResize(a, k + 1, 512);
      a[k] = price;
     }

   bool              PivotHigh(const CSmcBars &B, int p) const
     {
      for(int k = 1; k <= m_n; k++)
         if(B.b[p].h < B.b[p - k].h || B.b[p].h <= B.b[p + k].h)
            return false;
      return true;
     }
   bool              PivotLow(const CSmcBars &B, int p) const
     {
      for(int k = 1; k <= m_n; k++)
         if(B.b[p].l > B.b[p - k].l || B.b[p].l >= B.b[p + k].l)
            return false;
      return true;
     }
   void              AddHigh(const CSmcBars &B, int p)
     {
      if(m_last == 1 && B.b[p].h <= m_hPrice)
         return;   // đỉnh liền đỉnh: giữ cái cao hơn
      Record(m_highs, B.b[p].h, m_last == 1);
      m_hOk = true;
      m_hIdx = p;
      m_hPrice = B.b[p].h;
      m_hBroken = false;
      m_last = 1;
     }
   void              AddLow(const CSmcBars &B, int p)
     {
      if(m_last == -1 && B.b[p].l >= m_lPrice)
         return;
      Record(m_lows, B.b[p].l, m_last == -1);
      m_lOk = true;
      m_lIdx = p;
      m_lPrice = B.b[p].l;
      m_lBroken = false;
      m_last = -1;
     }
   void              MakeOb(const CSmcBars &B, SmcBreak &ev) const
     {
      ev.ob = false;
      ev.leg = -1;
      int from = ev.pivot + 1, to = ev.i - 1;
      if(from > to)
         return;
      int k = from;
      for(int j = from + 1; j <= to; j++)
         if(ev.dir > 0 ? B.b[j].l < B.b[k].l : B.b[j].h > B.b[k].h)
            k = j;
      ev.leg = k;
      if(B.b[k].h - B.b[k].l > 3.5 * B.b[ev.i].atr)
         return;   // OB quá cao: bỏ
      ev.ob = true;
      ev.obLo = B.b[k].l;
      ev.obHi = B.b[k].h;
     }

public:
   int               trend;   // 1 tăng, −1 giảm, 0 chưa có

   void              Init(int n)
     {
      m_n = n;
      m_last = 0;
      m_hOk = m_lOk = false;
      m_hBroken = m_lBroken = false;
      trend = 0;
      ArrayResize(m_highs, 0, 512);
      ArrayResize(m_lows, 0, 512);
     }

   // Đáy đã xác nhận gần nhất (về thời gian) có giá ≤ price; 0 nếu không có. NearestHigh: đỉnh gần nhất có giá ≥ price.
   double            NearestLow(double price) const
     {
      for(int k = ArraySize(m_lows) - 1; k >= 0; k--)
         if(m_lows[k] <= price)
            return m_lows[k];
      return 0.0;
     }
   double            NearestHigh(double price) const
     {
      for(int k = ArraySize(m_highs) - 1; k >= 0; k--)
         if(m_highs[k] >= price)
            return m_highs[k];
      return 0.0;
     }

   // Gọi sau khi thêm nến i. Trả về lần phá (nếu có) trong ev.
   void              OnBar(const CSmcBars &B, int i, SmcBreak &ev)
     {
      ev.valid = false;
      int p = i - m_n;
      if(p - m_n >= 0)
        {
         bool ph = PivotHigh(B, p), pl = PivotLow(B, p);
         if(ph && pl)
           {
            // cùng một nến vừa là đỉnh vừa là đáy: xử lý loại ngược với swing cuối trước
            if(m_last == 1)
              {
               AddLow(B, p);
               AddHigh(B, p);
              }
            else
              {
               AddHigh(B, p);
               AddLow(B, p);
              }
           }
         else
            if(ph)
               AddHigh(B, p);
            else
               if(pl)
                  AddLow(B, p);
        }
      if(m_hOk && !m_hBroken && B.b[i].c > m_hPrice)
        {
         m_hBroken = true;
         ev.valid = true;
         ev.dir = 1;
         ev.initial = trend == 0;
         ev.choch = trend == -1;
         ev.i = i;
         ev.pivot = m_hIdx;
         trend = 1;
         MakeOb(B, ev);
        }
      else
         if(m_lOk && !m_lBroken && B.b[i].c < m_lPrice)
           {
            m_lBroken = true;
            ev.valid = true;
            ev.dir = -1;
            ev.initial = trend == 0;
            ev.choch = trend == 1;
            ev.i = i;
            ev.pivot = m_lIdx;
            trend = -1;
            MakeOb(B, ev);
           }
     }
  };

struct SmcFvg
  {
   int               dir;
   double            top, bottom;
   double            atr;       // ATR lúc tạo
   int               i;         // nến thứ 3 (lúc xuất hiện)
   int               mid;       // nến giữa
   bool              touched;
   bool              dead;
  };

// FVG: khoảng trống > 0,25 ATR, nến giữa đóng vượt, không có nến nhảy giá; hỏng khi đóng qua mép xa; hết hạn 500 nến
class CSmcFvgs
  {
public:
   SmcFvg            f[];
   int               n;

   void              Init(void) { n = 0; ArrayResize(f, 0, 256); }

   void              OnBar(const CSmcBars &B, int i)
     {
      int keep = 0;
      for(int k = 0; k < n; k++)
        {
         if(f[k].i < i && !f[k].dead)
           {
            if(f[k].dir > 0)
              {
               if(B.b[i].l <= f[k].top)
                  f[k].touched = true;
               if(B.b[i].c < f[k].bottom)
                  f[k].dead = true;
              }
            else
              {
               if(B.b[i].h >= f[k].bottom)
                  f[k].touched = true;
               if(B.b[i].c > f[k].top)
                  f[k].dead = true;
              }
            if(i - f[k].i > 500)
               f[k].dead = true;
           }
         if(!f[k].dead)
            f[keep++] = f[k];
        }
      n = keep;
      ArrayResize(f, n, 256);
      if(i < 2 || B.b[i].jump || B.b[i - 1].jump)
         return;
      double atr = B.b[i].atr;
      if(B.b[i].l > B.b[i - 2].h && B.b[i - 1].c > B.b[i - 2].h && B.b[i].l - B.b[i - 2].h > 0.25 * atr)
         Push(1, B.b[i].l, B.b[i - 2].h, atr, i);
      if(B.b[i].h < B.b[i - 2].l && B.b[i - 1].c < B.b[i - 2].l && B.b[i - 2].l - B.b[i].h > 0.25 * atr)
         Push(-1, B.b[i - 2].l, B.b[i].h, atr, i);
     }

   void              Push(int dir, double top, double bottom, double atr, int i)
     {
      ArrayResize(f, n + 1, 256);
      f[n].dir = dir;
      f[n].top = top;
      f[n].bottom = bottom;
      f[n].atr = atr;
      f[n].i = i;
      f[n].mid = i - 1;
      f[n].touched = false;
      f[n].dead = false;
      n++;
     }

   // FVG còn mới (chưa chạm, chưa hỏng) mới nhất cùng chiều, nến giữa nằm trong (midFrom, midTo]; −1 nếu không có
   int               FindFresh(int dir, int midFrom, int midTo) const
     {
      int best = -1;
      for(int k = 0; k < n; k++)
         if(f[k].dir == dir && !f[k].touched && !f[k].dead && f[k].mid > midFrom && f[k].mid <= midTo && (best < 0 || f[k].i > f[best].i))
            best = k;
      return best;
     }
  };

struct SmcLevel
  {
   bool              high;      // true: bên mua (đỉnh), false: bên bán (đáy)
   double            price;
   int               idx;
   bool              swept;
  };

// Cú quét mức thanh khoản ở một nến
struct SmcSweep
  {
   bool              valid;
   int               dir;       // +1: quét đáy (bên bán) rồi đóng lại bên trên → hướng mua; −1 ngược lại
   double            extreme;   // low (hoặc high) của nến quét
   double            level;
   int               i;
  };

// Thanh khoản: đỉnh/đáy pivot 5/5; quét = râu vượt mức chưa phá, chưa quét, đóng quay lại; đóng vượt mức thì mức hết
class CSmcLiquidity
  {
private:
   int               m_n;
public:
   SmcLevel          v[];
   int               n;

   void              Init(int nPivot) { m_n = nPivot; n = 0; ArrayResize(v, 0, 256); }

   void              OnBar(const CSmcBars &B, int i, SmcSweep &up, SmcSweep &down)
     {
      up.valid = false;
      down.valid = false;
      int keep = 0;
      for(int k = 0; k < n; k++)
        {
         bool dead = i - v[k].idx > 500;
         if(v[k].high)
           {
            if(B.b[i].c > v[k].price)
               dead = true;
            else
               if(!v[k].swept && B.b[i].h > v[k].price)
                 {
                  v[k].swept = true;
                  if(!down.valid || v[k].price > down.level)
                    {
                     down.valid = true;
                     down.dir = -1;
                     down.extreme = B.b[i].h;
                     down.level = v[k].price;
                     down.i = i;
                    }
                 }
           }
         else
           {
            if(B.b[i].c < v[k].price)
               dead = true;
            else
               if(!v[k].swept && B.b[i].l < v[k].price)
                 {
                  v[k].swept = true;
                  if(!up.valid || v[k].price < up.level)
                    {
                     up.valid = true;
                     up.dir = 1;
                     up.extreme = B.b[i].l;
                     up.level = v[k].price;
                     up.i = i;
                    }
                 }
           }
         if(!dead)
            v[keep++] = v[k];
        }
      n = keep;
      ArrayResize(v, n, 256);
      // mức mới: pivot ở nến p = i − N, dùng được từ nến sau i
      int p = i - m_n;
      if(p - m_n < 0)
         return;
      bool ph = true, pl = true;
      for(int k = 1; k <= m_n; k++)
        {
         if(B.b[p].h < B.b[p - k].h || B.b[p].h <= B.b[p + k].h)
            ph = false;
         if(B.b[p].l > B.b[p - k].l || B.b[p].l >= B.b[p + k].l)
            pl = false;
        }
      if(ph)
         Push(true, B.b[p].h, p);
      if(pl)
         Push(false, B.b[p].l, p);
     }

   void              Push(bool high, double price, int idx)
     {
      ArrayResize(v, n + 1, 256);
      v[n].high = high;
      v[n].price = price;
      v[n].idx = idx;
      v[n].swept = false;
      n++;
     }

   // Mức bên mua (đỉnh) chưa quét gần nhất phía trên price (dir = +1), hoặc bên bán phía dưới (dir = −1); 0 nếu không có
   double            Nearest(int dir, double price) const
     {
      double best = 0.0;
      for(int k = 0; k < n; k++)
        {
         if(v[k].swept || v[k].high != (dir > 0))
            continue;
         if(dir > 0 && v[k].price > price && (best == 0.0 || v[k].price < best))
            best = v[k].price;
         if(dir < 0 && v[k].price < price && (best == 0.0 || v[k].price > best))
            best = v[k].price;
        }
      return best;
     }
  };

#endif
