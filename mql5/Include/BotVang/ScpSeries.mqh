// ScpSeries.mqh — chuỗi nến, chỉ báo, pivot và hướng khung cho bot SCP-MTF-1.0.
// Nguồn luật: docs/SPEC.md mục 4, 5.1 (EMA), 14.1, 14.2.
// File chỉ tính trên nến đã đóng do bên gọi đưa vào; không đọc MT5, không gửi lệnh.
#ifndef SCP_SERIES_MQH
#define SCP_SERIES_MQH

#include "ScpTypes.mqh"

#define SCP_MAX_BARS      1500
#define SCP_MAX_PIVOTS    300
#define SCP_ATR_PERIOD    14
#define SCP_PIVOT_N_M1M5  2
#define SCP_PIVOT_N_M15H1 3
#define SCP_PIVOT_N_H4D1  2
#define SCP_K_BUFFER      0.10   // đệm hình học theo ATR_ref (SPEC mục 13)

class ScpSeries
  {
private:
   ENUM_SCP_TF       m_tf;
   ScpBar            m_bars[SCP_MAX_BARS];
   int               m_count;
   int               m_start;        // chỉ số phần tử cũ nhất trong vòng
   double            m_atr[SCP_MAX_BARS];
   double            m_ema20[SCP_MAX_BARS];
   double            m_ema50[SCP_MAX_BARS];
   double            m_ema200[SCP_MAX_BARS];
   ScpPivot          m_pivots[SCP_MAX_PIVOTS];
   int               m_pivot_count;
   long              m_next_pivot_id;
   ScpFrameInfo      m_info;
   int               m_pivot_n;
   bool              m_has_ema;
   bool              m_pending_up;   // hướng gốc khi đang TRANSITION

   int               Phys(int idx) { return (m_start + idx) % SCP_MAX_BARS; }

   void              RecomputeIndicators()
     {
      // Cập nhật đúng một nến. Kết quả trước vẫn giữ khi vòng bộ nhớ quay.
      int n=m_count, idx=Phys(n-1), prev=Phys(MathMax(0,n-2));
      double pc=n>1 ? m_bars[prev].c : m_bars[idx].o;
      double tr=MathMax(m_bars[idx].h-m_bars[idx].l,
                        MathMax(MathAbs(m_bars[idx].h-pc),MathAbs(m_bars[idx].l-pc)));
      m_atr[idx]=n==1 ? tr : (m_atr[prev]*(SCP_ATR_PERIOD-1)+tr)/SCP_ATR_PERIOD;
      if(!m_has_ema) return;
      double c=m_bars[idx].c;
      m_ema20[idx]=0; m_ema50[idx]=0; m_ema200[idx]=0;
      if(n==20 || n==50 || n==200)
        {
         double sum=0;
         for(int i=0;i<n;i++) sum+=m_bars[Phys(i)].c;
         if(n==20) m_ema20[idx]=sum/20;
         if(n==50) m_ema50[idx]=sum/50;
         if(n==200) m_ema200[idx]=sum/200;
        }
      if(n>20) m_ema20[idx]=c*(2.0/21)+m_ema20[prev]*(1-2.0/21);
      if(n>50) m_ema50[idx]=c*(2.0/51)+m_ema50[prev]*(1-2.0/51);
      if(n>200) m_ema200[idx]=c*(2.0/201)+m_ema200[prev]*(1-2.0/201);
     }

   void              AddPivot(bool is_high, const ScpBar &src, datetime known_at, bool ambiguous)
     {
      if(m_pivot_count >= SCP_MAX_PIVOTS)
        {
         // Giữ mốc bảo vệ nếu nó còn cần, thu hồi phần tử khác lâu nhất.
         int drop = (m_pivots[0].id == m_info.protected_pivot_id) ? 1 : 0;
         for(int j = drop; j < m_pivot_count - 1; j++) m_pivots[j] = m_pivots[j + 1];
         m_pivot_count--;
        }
      ScpPivot p;
      p.id = m_next_pivot_id++;
      p.is_high = is_high;
      p.price = is_high ? src.h : src.l;
      p.bar_time = src.open_time;
      p.known_at = known_at;
      p.ambiguous = ambiguous;
      p.used = false;
      m_pivots[m_pivot_count++] = p;
     }

   void              ScanPivot()
     {
      int candidate = m_count - 1 - m_pivot_n;
      if(candidate < m_pivot_n)
         return;
      ScpBar cand = m_bars[Phys(candidate)];
      bool high_ok = true, low_ok = true;
      for(int k = 1; k <= m_pivot_n; k++)
        {
         if(high_ok)
           {
            if(!(cand.h >= m_bars[Phys(candidate - k)].h) || !(cand.h > m_bars[Phys(candidate + k)].h))
               high_ok = false;
           }
         if(low_ok)
           {
            if(!(cand.l <= m_bars[Phys(candidate - k)].l) || !(cand.l < m_bars[Phys(candidate + k)].l))
               low_ok = false;
           }
        }
      if(!high_ok && !low_ok)
         return;
      datetime known = m_bars[Phys(candidate + m_pivot_n)].known_at;
      bool ambiguous = (high_ok && low_ok);
      if(high_ok)
         AddPivot(true, cand, known, ambiguous);
      if(low_ok)
         AddPivot(false, cand, known, ambiguous);
     }

   int               LastPivot(bool is_high)
     {
      for(int i = m_pivot_count - 1; i >= 0; i--)
         if(m_pivots[i].is_high == is_high && !m_pivots[i].ambiguous)
            return i;
      return -1;
     }

   int               PrevPivot(bool is_high, int from)
     {
      for(int i = from - 1; i >= 0; i--)
         if(m_pivots[i].is_high == is_high && !m_pivots[i].ambiguous)
            return i;
      return -1;
     }

   void              UpdateDirection(double eps)
     {
      int h2 = LastPivot(true);
      int l2 = LastPivot(false);
      int h1 = (h2 >= 0) ? PrevPivot(true, h2) : -1;
      int l1 = (l2 >= 0) ? PrevPivot(false, l2) : -1;
      bool pair_up = (h1 >= 0 && h2 >= 0 && l1 >= 0 && l2 >= 0 &&
                      m_pivots[h2].price > m_pivots[h1].price && m_pivots[l2].price > m_pivots[l1].price);
      bool pair_down = (h1 >= 0 && h2 >= 0 && l1 >= 0 && l2 >= 0 &&
                        m_pivots[h2].price < m_pivots[h1].price && m_pivots[l2].price < m_pivots[l1].price);
      if(pair_up && !(m_info.dir==SCP_DIR_TRANSITION && m_pending_up))
        {
         if(m_info.dir != SCP_DIR_UP)
           {
            m_info.dir = SCP_DIR_UP;
            m_info.protected_pivot_id = m_pivots[l2].id;
           }
         m_pending_up = true;
        }
      else
         if(pair_down && !(m_info.dir==SCP_DIR_TRANSITION && !m_pending_up))
           {
            if(m_info.dir != SCP_DIR_DOWN)
              {
               m_info.dir = SCP_DIR_DOWN;
               m_info.protected_pivot_id = m_pivots[h2].id;
              }
            m_pending_up = false;
           }
      if(m_count <= 0)
         return;
      double close = m_bars[Phys(m_count - 1)].c;
      double prot = ProtectedPrice();
      if(prot <= 0.0)
         return;
      if(m_info.dir == SCP_DIR_UP)
        {
         int hp = LastPivot(true);
         if(hp >= 0 && close > m_pivots[hp].price + eps)
           {
            int lp = LastPivot(false);
            if(lp >= 0 && m_pivots[lp].price>prot)
               m_info.protected_pivot_id = m_pivots[lp].id;
           }
         if(close < prot - eps)
            m_info.dir = SCP_DIR_TRANSITION;
        }
      else
         if(m_info.dir == SCP_DIR_DOWN)
           {
            int lp = LastPivot(false);
            if(lp >= 0 && close < m_pivots[lp].price - eps)
              {
               int hp = LastPivot(true);
               if(hp >= 0 && m_pivots[hp].price<prot)
                  m_info.protected_pivot_id = m_pivots[hp].id;
              }
            if(close > prot + eps)
               m_info.dir = SCP_DIR_TRANSITION;
           }
      else
         if(m_info.dir == SCP_DIR_TRANSITION)
           {
            // Quay lại đúng hướng gốc khi đóng vượt lại mốc bảo vệ.
            if(m_pending_up && close > prot + eps)
               m_info.dir = SCP_DIR_UP;
            else
               if(!m_pending_up && close < prot - eps)
                  m_info.dir = SCP_DIR_DOWN;
           }
     }

public:
                     ScpSeries()
     {
      m_tf = SCP_TF_M1;
      m_count = 0;
      m_start = 0;
      m_pivot_count = 0;
      m_next_pivot_id = 1;
      m_pivot_n = SCP_PIVOT_N_M1M5;
      m_has_ema = false;
      m_pending_up = true;
      m_info.dir = SCP_DIR_UNDEFINED;
      m_info.protected_pivot_id = -1;
      m_info.last_closed_at = 0;
      m_info.known_at = 0;
      m_info.data_ok = false;
      m_info.atr = 0.0;
     }

   void              Init(ENUM_SCP_TF tf)
     {
      m_tf = tf;
      m_has_ema = (tf == SCP_TF_M5 || tf == SCP_TF_M15 || tf == SCP_TF_H1);
      if(tf == SCP_TF_M1 || tf == SCP_TF_M5)
         m_pivot_n = SCP_PIVOT_N_M1M5;
      else
         if(tf == SCP_TF_M15 || tf == SCP_TF_H1)
            m_pivot_n = SCP_PIVOT_N_M15H1;
         else
            m_pivot_n = SCP_PIVOT_N_H4D1;
     }

   int               Count() { return m_count; }
   ENUM_SCP_TF       Tf() { return m_tf; }
   ScpFrameInfo      Info() { return m_info; }
   ENUM_SCP_DIR      Dir() { return m_info.dir; }
   double            Atr() { return m_info.atr; }
   int               PivotCount() { return m_pivot_count; }
   ScpPivot          Pivot(int i) { return m_pivots[i]; }
   int               PivotN() { return m_pivot_n; }

   ScpBar            Bar(int idx)
     {
      ScpBar empty;
      empty.open_time = 0;
      empty.close_time = 0;
      empty.o = empty.h = empty.l = empty.c = 0.0;
      empty.tick_volume = 0;
      empty.known_at = 0;
      empty.known_at_msc = -1;
      empty.complete = false;
      if(idx < 0 || idx >= m_count)
         return empty;
      return m_bars[Phys(idx)];
     }

   ScpBar            LastBar() { return Bar(m_count - 1); }

   double            AtrAt(int idx)
     {
      if(idx < 0 || idx >= m_count)
         return 0.0;
      return m_atr[Phys(idx)];
     }

   double            Ema(int period, int idx)
     {
      if(idx < 0 || idx >= m_count)
         return 0.0;
      if(period == 20)
         return m_ema20[Phys(idx)];
      if(period == 50)
         return m_ema50[Phys(idx)];
      if(period == 200)
         return m_ema200[Phys(idx)];
      return 0.0;
     }

   bool              EmaReady(int period) { return (m_count >= period); }

   double            ProtectedPrice()
     {
      if(m_info.protected_pivot_id < 0)
         return 0.0;
      for(int i = 0; i < m_pivot_count; i++)
         if(m_pivots[i].id == m_info.protected_pivot_id)
            return m_pivots[i].price;
      return 0.0;
     }

   long              LastPivotId(bool is_high)
     {
      int i = LastPivot(is_high);
      return (i >= 0) ? m_pivots[i].id : -1;
     }

   double            LastPivotPrice(bool is_high)
     {
      int i = LastPivot(is_high);
      return (i >= 0) ? m_pivots[i].price : 0.0;
     }

   datetime          LastPivotBarTime(bool is_high)
     {
      int i = LastPivot(is_high);
      return i >= 0 ? m_pivots[i].bar_time : 0;
     }

   datetime          LastPivotKnownAt(bool is_high)
     {
      int i = LastPivot(is_high);
      return (i >= 0) ? m_pivots[i].known_at : 0;
     }

   // Đỉnh/đáy nhỏ đã biết trước `known_before`, nằm trong `lookback` nến trước mốc `before_index`.
   double            SmallPivot(bool want_high, int before_index, int lookback, datetime known_before)
     {
      int stop = MathMax(0, before_index - lookback);
      int end = MathMin(before_index, m_count);
      for(int i = m_pivot_count - 1; i >= 0; i--)
        {
         if(m_pivots[i].is_high != want_high)
            continue;
         if(m_pivots[i].ambiguous)
            continue;
         if(m_pivots[i].known_at > known_before)
            continue;
         for(int b = stop; b < end; b++)
            if(m_bars[Phys(b)].open_time == m_pivots[i].bar_time)
               return m_pivots[i].price;
        }
      return 0.0;
     }

   // Xóa toàn bộ chuỗi để dùng lại cho ca kiểm khác.
   void              Reset()
     {
      m_count = 0;
      m_start = 0;
      m_pivot_count = 0;
      m_next_pivot_id = 1;
      m_pending_up = true;
      m_info.dir = SCP_DIR_UNDEFINED;
      m_info.protected_pivot_id = -1;
      m_info.last_closed_at = 0;
      m_info.known_at = 0;
      m_info.data_ok = false;
      m_info.atr = 0.0;
     }

   // Đưa một nến đã đóng hợp lệ vào chuỗi. Trả về false nếu nến sai định dạng.
   bool              PushBar(const ScpBar &bar)
     {
      if(bar.close_time<=bar.open_time || bar.known_at<bar.close_time) return false;
      if(!bar.complete || !MathIsValidNumber(bar.o) || !MathIsValidNumber(bar.h) ||
         !MathIsValidNumber(bar.l) || !MathIsValidNumber(bar.c)) return false;
      if(!(bar.h >= MathMax(bar.o, bar.c)))
         return false;
      if(!(bar.l <= MathMin(bar.o, bar.c)))
         return false;
      if(!(bar.h >= bar.l) || bar.o <= 0.0 || bar.h <= 0.0 || bar.l <= 0.0 || bar.c <= 0.0)
         return false;
      if(m_count > 0 && bar.open_time <= m_bars[Phys(m_count - 1)].open_time)
         return false;
      if(m_count < SCP_MAX_BARS)
        {
         m_bars[Phys(m_count)] = bar;
         m_count++;
        }
      else
        {
         m_bars[m_start] = bar;
         m_start = (m_start + 1) % SCP_MAX_BARS;
        }
      RecomputeIndicators();
      m_info.atr = m_atr[Phys(m_count - 1)];
      m_info.data_ok = (m_count >= SCP_ATR_PERIOD + 2);
      double eps = SCP_K_BUFFER * m_info.atr;
      ScanPivot();
      UpdateDirection(eps);
      m_info.last_closed_at = bar.close_time;
      m_info.known_at = bar.known_at;
      return true;
     }
  };

// Bộ sáu chuỗi nến của một ký hiệu.
class ScpFrames
  {
private:
   ScpSeries         m_s[SCP_TF_COUNT];

public:
   void              Init()
     {
      for(int i = 0; i < SCP_TF_COUNT; i++)
        { m_s[i].Reset(); m_s[i].Init((ENUM_SCP_TF)i); }
     }

   ScpSeries        *Get(ENUM_SCP_TF tf)
     {
      if(tf < 0 || tf >= SCP_TF_COUNT)
         return NULL;
      return GetPointer(m_s[tf]);
     }

   ScpSeries        *Get(int tf) { return Get((ENUM_SCP_TF)tf); }

   void              ResetAll()
     {
      for(int i = 0; i < SCP_TF_COUNT; i++)
         m_s[i].Reset();
     }

   bool              AllReady()
     {
      for(int i = 0; i < SCP_TF_COUNT; i++)
         if(!m_s[i].Info().data_ok)
            return false;
      return true;
     }
  };

#endif // SCP_SERIES_MQH
