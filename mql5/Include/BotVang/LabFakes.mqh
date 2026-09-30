// Vùng giả đối chứng của BotVangLab: sinh quanh vùng thật lúc vùng thật được tạo, dịch cả dải
// ± U(0,5; 3) × biến động, rồi đi qua cùng luật phá/lật/chạm (ZoneStep). Nằm riêng, không ảnh hưởng vùng thật
// (không chặn trùng, không hợp lưu, không làm cản, không tính vào giới hạn 60 vùng của vùng thật).
#ifndef BOTVANG_LABFAKES_MQH
#define BOTVANG_LABFAKES_MQH

#include "Zones.mqh"
#include "LabRandom.mqh"

// Số vùng giả mỗi vùng thật trước khi nhân hệ số: khung lớn ít sự kiện hơn nên cần nhiều vùng giả hơn
int FakesBase(ENUM_TIMEFRAMES tf)
  {
   switch(tf)
     {
      case PERIOD_M15: return 5;
      case PERIOD_H1:  return 10;
      case PERIOD_H4:  return 20;
      default:         return 10;
     }
  }

// Vùng giả có đang chồng lên vùng thật còn sống nào không (vùng thật tạo sau vẫn có thể đè lên vùng giả)
bool FakeOverlapsReal(const Zone &f, const Zone &reals[], int nReal)
  {
   for(int j = 0; j < nReal; j++)
      if(!reals[j].dead && f.lo <= reals[j].hi && reals[j].lo <= f.hi)
         return true;
   return false;
  }

#define FAKE_MAX_MULT 10

class CFakeZones
  {
private:
   ZoneRules         m_rules;
   ulong             m_seed;
   int               m_nextId;

   static bool       Overlap(double lo1, double hi1, double lo2, double hi2) { return lo1 <= hi2 && lo2 <= hi1; }

public:
   Zone              zones[];
   int               count;
   Zone              evZone[];   // vùng giả có sự kiện ở nến vừa đóng (trạng thái sau nến)
   int               evFlags[];
   int               evCount;
   int               spawned;
   int               notPlaced;  // số vùng giả không đặt được sau 50 lần rút
   int               droppedCap;

   int               mult;       // hệ số nhân số vùng giả (kho ghép cặp đủ lớn)

   int               PerZone(ENUM_TIMEFRAMES tf) const { return FakesBase(tf) * mult; }
   int               MaxCopies(void) const { return 20 * mult; }

   void              Init(const ZoneRules &rules, ulong seed, int multiplier)
     {
      mult = MathMax(1, MathMin(FAKE_MAX_MULT, multiplier));
      m_rules = rules;
      m_seed = seed;
      m_nextId = 1000000000;
      count = 0;
      evCount = 0;
      spawned = 0;
      notPlaced = 0;
      droppedCap = 0;
     }

   // Sinh vùng giả cho một vùng thật vừa tạo. Vị trí chỉ phụ thuộc hạt giống, vùng thật và các vùng thật đang có.
   // Luật đặt: cùng phía giá như vùng thật; không chồng dải vùng thật còn sống cùng khung (mọi vai).
   // Vùng thật khác khung rất dày nên không thể tránh hết lúc đặt; thay vào đó, sự kiện của vùng giả đang chồng lên
   // bất kỳ vùng thật nào lúc chạm bị loại khỏi kho đối chứng (FakeOverlapsReal).
   void              Spawn(const Zone &real, const Zone &reals[], int nReal, double price)
     {
      CRng rng;
      ulong h = RngMix(m_seed, (ulong)real.tf);
      h = RngMix(h, (ulong)real.kind * 2 + (real.isRes ? 1 : 0));
      h = RngMix(h, (ulong)real.created);
      rng.Seed(RngMix(h, (ulong)(long)MathRound(real.level * 1000.0)));
      bool above = real.level > price;
      int n = PerZone(real.tf);
      for(int i = 0; i < n; i++)
        {
         bool placed = false;
         for(int t = 0; t < 50 && !placed; t++)
           {
            double off = (rng.Below(2) == 0 ? 1.0 : -1.0) * (0.5 + 2.5 * rng.Uniform()) * real.atr;
            double lo = real.lo + off, hi = real.hi + off, level = real.level + off;
            if((level > price) != above || Overlap(lo, hi, real.lo, real.hi))
               continue;
            bool clash = false;
            for(int j = 0; j < nReal && !clash; j++)
               clash = !reals[j].dead && reals[j].tf == real.tf && Overlap(lo, hi, reals[j].lo, reals[j].hi);
            if(clash)
               continue;
            Zone f = real;
            f.id = m_nextId++;
            f.parent = real.id;
            f.copy = i + 1;
            f.level = level;
            f.lo = lo;
            f.hi = hi;
            f.score = 0;
            ArrayResize(zones, count + 1, 256);
            zones[count++] = f;
            spawned++;
            placed = true;
           }
         if(!placed)
            notPlaced++;
        }
     }

   // Cập nhật mọi vùng giả bằng nến M5 vừa đóng; gom sự kiện
   void              Step(const MqlRates &b, double atrM5)
     {
      evCount = 0;
      for(int i = 0; i < count; i++)
        {
         if(zones[i].dead || b.time < zones[i].created)
            continue;
         int ev = ZoneStep(zones[i], b, atrM5, m_rules);
         if(ev == 0)
            continue;
         ArrayResize(evZone, evCount + 1, 64);
         ArrayResize(evFlags, evCount + 1, 64);
         evZone[evCount] = zones[i];
         evFlags[evCount] = ev;
         evCount++;
        }
     }

   // Xóa như vùng thật (bị phá lần hai, quá xa, hết hạn); giới hạn mỗi khung = 60 × số vùng giả mỗi vùng thật
   void              Prune(double price, datetime now, double atrH1)
     {
      int keep = 0;
      for(int i = 0; i < count; i++)
        {
         bool far = atrH1 > 0.0 && MathAbs(zones[i].level - price) > m_rules.farAtrH1 * atrH1;
         if(zones[i].dead || far || ZoneExpired(zones[i], now, m_rules))
            continue;
         if(keep != i)
            zones[keep] = zones[i];
         keep++;
        }
      count = keep;
      ENUM_TIMEFRAMES tfs[4] = {PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1};
      for(int t = 0; t < 4; t++)
        {
         int cap = m_rules.maxPerTf * PerZone(tfs[t]);
         int n = 0;
         for(int i = 0; i < count; i++)
            if(zones[i].tf == tfs[t])
               n++;
         if(n <= cap)
            continue;
         // bỏ các vùng tạo sớm nhất: đánh dấu rồi dồn mảng một lần
         while(n > cap)
           {
            int oldest = -1;
            for(int i = 0; i < count; i++)
               if(!zones[i].dead && zones[i].tf == tfs[t] && (oldest < 0 || zones[i].created < zones[oldest].created))
                  oldest = i;
            zones[oldest].dead = true;
            droppedCap++;
            n--;
           }
         keep = 0;
         for(int i = 0; i < count; i++)
           {
            if(zones[i].dead)
               continue;
            if(keep != i)
               zones[keep] = zones[i];
            keep++;
           }
         count = keep;
        }
      ArrayResize(zones, count, 256);
     }
  };

#endif
