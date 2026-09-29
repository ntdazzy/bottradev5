// Thống kê của BotVangLab (SPEC §16.5–16.6): khoảng Wilson, mức hòa vốn p*_k, bootstrap theo khối ngày.
#ifndef BOTVANG_LABSTATS_MQH
#define BOTVANG_LABSTATS_MQH

#include "LabRandom.mqh"

// Nghịch đảo phân phối chuẩn (xấp xỉ Acklam, sai số < 1e-8). NormInv(0,975) = 1,95996.
double NormInv(double p)
  {
   const double a1 = -3.969683028665376e+01, a2 = 2.209460984245205e+02, a3 = -2.759285104469687e+02;
   const double a4 = 1.383577518672690e+02, a5 = -3.066479806614716e+01, a6 = 2.506628277459239e+00;
   const double b1 = -5.447609879822406e+01, b2 = 1.615858368580409e+02, b3 = -1.556989798598866e+02;
   const double b4 = 6.680131188771972e+01, b5 = -1.328068155288572e+01;
   const double c1 = -7.784894002430293e-03, c2 = -3.223964580411365e-01, c3 = -2.400758277161838e+00;
   const double c4 = -2.549732539343734e+00, c5 = 4.374664141464968e+00, c6 = 2.938163982698783e+00;
   const double d1 = 7.784695709041462e-03, d2 = 3.224671290700398e-01, d3 = 2.445134137142996e+00;
   const double d4 = 3.754408661907416e+00;
   if(p <= 0.0 || p >= 1.0)
      return 0.0;
   if(p < 0.02425)
     {
      double q = MathSqrt(-2.0 * MathLog(p));
      return (((((c1 * q + c2) * q + c3) * q + c4) * q + c5) * q + c6) / ((((d1 * q + d2) * q + d3) * q + d4) * q + 1.0);
     }
   if(p > 1.0 - 0.02425)
     {
      double q = MathSqrt(-2.0 * MathLog(1.0 - p));
      return -(((((c1 * q + c2) * q + c3) * q + c4) * q + c5) * q + c6) / ((((d1 * q + d2) * q + d3) * q + d4) * q + 1.0);
     }
   double q = p - 0.5, r = q * q;
   return (((((a1 * r + a2) * r + a3) * r + a4) * r + a5) * r + a6) * q / (((((b1 * r + b2) * r + b3) * r + b4) * r + b5) * r + 1.0);
  }

// Khoảng Wilson cho tỉ lệ k/n với hệ số z
void Wilson(int k, int n, double z, double &lo, double &hi)
  {
   if(n <= 0)
     {
      lo = 0.0;
      hi = 1.0;
      return;
     }
   double p = (double)k / n, z2 = z * z;
   double den = 1.0 + z2 / n;
   double centre = p + z2 / (2.0 * n);
   double margin = z * MathSqrt(p * (1.0 - p) / n + z2 / (4.0 * n * n));
   lo = MathMax(0.0, (centre - margin) / den);
   hi = MathMin(1.0, (centre + margin) / den);
  }

// Mức hòa vốn với mục tiêu +kB, dừng −1B, chi phí ngoài chênh lệch c (theo giá) (§16.5)
double BreakEvenP(double B, double c, int k) { return (B + c) / ((k + 1) * B); }

// Mẫu theo sự kiện, có ngày (khối) để bootstrap. Thống kê = tổng x / số sự kiện.
class CSamples
  {
private:
   int               m_day[];
   double            m_x[];
   int               m_n;

   // Tổng x và số sự kiện theo từng ngày có sự kiện (ngày tăng dần)
   void              DayTotals(double &num[], double &den[]) const
     {
      int d[];
      ArrayCopy(d, m_day, 0, 0, m_n);
      ArraySort(d);
      int uniq[];
      int nd = 0;
      for(int i = 0; i < m_n; i++)
         if(i == 0 || d[i] != d[i - 1])
           {
            ArrayResize(uniq, nd + 1, 64);
            uniq[nd++] = d[i];
           }
      ArrayResize(num, nd);
      ArrayResize(den, nd);
      ArrayInitialize(num, 0.0);
      ArrayInitialize(den, 0.0);
      for(int i = 0; i < m_n; i++)
        {
         int k = ArrayBsearch(uniq, m_day[i]);
         num[k] += m_x[i];
         den[k] += 1.0;
        }
     }
public:
                     CSamples(void) : m_n(0) {}
   void              Reset(void) { m_n = 0; ArrayResize(m_day, 0); ArrayResize(m_x, 0); }
   void              Add(int day, double x)
     {
      ArrayResize(m_day, m_n + 1, 256);
      ArrayResize(m_x, m_n + 1, 256);
      m_day[m_n] = day;
      m_x[m_n] = x;
      m_n++;
     }
   int               Count(void) const { return m_n; }
   double            Mean(void) const
     {
      if(m_n == 0)
         return 0.0;
      double s = 0.0;
      for(int i = 0; i < m_n; i++)
         s += m_x[i];
      return s / m_n;
     }
   // Số ngày khác nhau có ít nhất 1 sự kiện
   int               Days(void) const
     {
      int d[];
      ArrayCopy(d, m_day, 0, 0, m_n);
      ArraySort(d);
      int n = 0;
      for(int i = 0; i < m_n; i++)
         if(i == 0 || d[i] != d[i - 1])
            n++;
      return n;
     }
   // Bootstrap theo khối ngày: rút có hoàn lại D ngày (D = số ngày có sự kiện), iters lần; cận = giá trị thứ rank từ hai đầu.
   bool              CI(int iters, ulong seed, int rank, double &lo, double &hi) const
     {
      if(m_n == 0 || rank < 1 || 2 * rank > iters)
         return false;
      int d[];
      ArrayCopy(d, m_day, 0, 0, m_n);
      ArraySort(d);
      int uniq[];
      int nd = 0;
      for(int i = 0; i < m_n; i++)
         if(i == 0 || d[i] != d[i - 1])
           {
            ArrayResize(uniq, nd + 1, 64);
            uniq[nd++] = d[i];
           }
      double num[], den[];
      ArrayResize(num, nd);
      ArrayResize(den, nd);
      ArrayInitialize(num, 0.0);
      ArrayInitialize(den, 0.0);
      for(int i = 0; i < m_n; i++)
        {
         int k = ArrayBsearch(uniq, m_day[i]);
         num[k] += m_x[i];
         den[k] += 1.0;
        }
      double stats[];
      ArrayResize(stats, iters);
      CRng r;
      r.Seed(seed);
      for(int it = 0; it < iters; it++)
        {
         double sn = 0.0, sd = 0.0;
         for(int j = 0; j < nd; j++)
           {
            int k = r.Below(nd);
            sn += num[k];
            sd += den[k];
           }
         stats[it] = sd > 0.0 ? sn / sd : 0.0;
        }
      ArraySort(stats);
      lo = stats[rank - 1];
      hi = stats[iters - rank];
      return true;
     }
   // Hiệu trung bình (nhóm này − nhóm other) của hai nhóm độc lập: mỗi lần rút lại ngày có hoàn lại riêng cho từng nhóm
   // (số ngày rút = số ngày có sự kiện của nhóm đó), iters lần; cận = giá trị thứ rank từ hai đầu (SPEC §22.4).
   bool              DiffCI(const CSamples &other, int iters, ulong seed, int rank, double &lo, double &hi) const
     {
      if(m_n == 0 || other.m_n == 0 || rank < 1 || 2 * rank > iters)
         return false;
      double an[], ad[], bn[], bd[];
      DayTotals(an, ad);
      other.DayTotals(bn, bd);
      int na = ArraySize(an), nb = ArraySize(bn);
      double stats[];
      ArrayResize(stats, iters);
      CRng r;
      r.Seed(seed);
      for(int it = 0; it < iters; it++)
        {
         double sa = 0.0, da = 0.0, sb = 0.0, db = 0.0;
         for(int j = 0; j < na; j++)
           {
            int k = r.Below(na);
            sa += an[k];
            da += ad[k];
           }
         for(int j = 0; j < nb; j++)
           {
            int k = r.Below(nb);
            sb += bn[k];
            db += bd[k];
           }
         stats[it] = sa / da - sb / db;
        }
      ArraySort(stats);
      lo = stats[rank - 1];
      hi = stats[iters - rank];
      return true;
     }
  };

// Thứ hạng cận của bootstrap cho mức sai alpha (hai phía), ví dụ 2.000 lần, alpha 0,05 → 50; alpha 0,05/3 → 17
int BootRank(int iters, double alpha) { return MathMax(1, (int)MathRound(iters * alpha / 2.0)); }

#endif
