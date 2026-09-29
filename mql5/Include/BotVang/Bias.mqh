// Hướng lớn theo phá đỉnh/đáy xoay trên H4 và H1
#ifndef BOTVANG_BIAS_MQH
#define BOTVANG_BIAS_MQH

#include "Types.mqh"

// 1 = TĂNG, -1 = GIẢM, 0 = chưa rõ
int StructureBias(const string sym, ENUM_TIMEFRAMES tf, int bars = 300)
  {
   const int R = 3;
   MqlRates r[];
   ArraySetAsSeries(r, true);
   int n = CopyRates(sym, tf, 1, bars, r);   // chỉ nến đã đóng
   if(n < 2 * R + 10)
      return 0;
   double lastHigh = 0.0, lastLow = 0.0;
   bool hiLive = false, loLive = false;
   int bias = 0;
   for(int i = n - 1; i >= 0; i--)
     {
      int j = i + R;   // nến có đủ R nến mới hơn tính tới nến i
      if(j + R < n)
        {
         bool ph = true, pl = true;
         for(int k = 1; k <= R; k++)
           {
            if(r[j + k].high > r[j].high || r[j - k].high >= r[j].high)
               ph = false;
            if(r[j + k].low < r[j].low || r[j - k].low <= r[j].low)
               pl = false;
           }
         if(ph)
           {
            lastHigh = r[j].high;
            hiLive = true;
           }
         if(pl)
           {
            lastLow = r[j].low;
            loLive = true;
           }
        }
      if(hiLive && r[i].close > lastHigh)
        {
         bias = 1;
         hiLive = false;
        }
      if(loLive && r[i].close < lastLow)
        {
         bias = -1;
         loLive = false;
        }
     }
   return bias;
  }

int CombinedBias(int h4, int h1, ENUM_BIAS_MODE mode)
  {
   if(mode == BIAS_H1_ONLY)
      return h1;
   if(mode == BIAS_H4_ONLY)
      return h4;
   return h4 == h1 ? h4 : 0;
  }

// Đáy/đỉnh xoay gần nhất trên M5 (2 nến mỗi bên), dùng để nhận "bị đẩy lại" tại cản
double RecentSwingM5(const string sym, bool low)
  {
   MqlRates r[];
   ArraySetAsSeries(r, true);
   int n = CopyRates(sym, PERIOD_M5, 1, 40, r);
   for(int k = 3; k + 2 < n; k++)
     {
      bool ok = true;
      for(int j = 1; j <= 2; j++)
         if(low ? (r[k + j].low < r[k].low || r[k - j].low <= r[k].low)
                : (r[k + j].high > r[k].high || r[k - j].high >= r[k].high))
            ok = false;
      if(ok)
         return low ? r[k].low : r[k].high;
     }
   return 0.0;
  }

#endif
