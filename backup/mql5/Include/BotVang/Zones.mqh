// Vùng giá: tìm mức A/V, Gap, đỉnh/đáy cũ; cập nhật trạng thái trên nến M5 đã đóng;
// chấm điểm sức mạnh. ZoneStep/ZoneScore dùng chung cho vùng thật và vùng giả của BotVangLab.
// Mọi việc chạy theo thời gian của nến M5 vừa đóng (Step), nên lúc nạp lịch sử và lúc chạy đi cùng một đường code.
#ifndef BOTVANG_ZONES_MQH
#define BOTVANG_ZONES_MQH

#include "Types.mqh"

#define ZONE_TF_COUNT 4
#define ZONE_REFERENCE_FROM 3   // ReferenceOnlyFromTouch: từ lần chạm 3 chỉ còn tham khảo

// Lần chạm thứ mấy nếu giá tới vùng lúc này: đã rời xa thì là lần kế tiếp, đang ở trong/sát vùng thì là lần hiện tại.
int ZoneApproachN(const Zone &z) { return z.away ? z.touches + 1 : MathMax(z.touches, 1); }

// Vùng còn làm cản được không (lần chạm 1–2)
bool ZoneIsBarrier(const Zone &z) { return !z.dead && ZoneApproachN(z) < ZONE_REFERENCE_FROM; }

// [ỨNG VIÊN] hết hạn: vùng M15 sau expireM15Hours giờ; vùng khung lớn sau expireHtfDays ngày (0 = không hết hạn)
bool ZoneExpired(const Zone &z, datetime now, const ZoneRules &r)
  {
   if(z.tf == PERIOD_M15)
      return r.expireM15Hours > 0 && now - z.created > r.expireM15Hours * 3600;
   return r.expireHtfDays > 0 && now - z.created > r.expireHtfDays * 86400;
  }

// Cập nhật một vùng bằng một nến M5 đã đóng. Trả về các bit ZEV_*.
int ZoneStep(Zone &z, const MqlRates &b, double atrM5, const ZoneRules &r)
  {
   if(z.dead)
      return 0;
   int ev = 0;
   double tol = 0.1 * z.atr;
   z.barsAlive++;
   if(z.flips == 1)
      z.barsSinceFlip++;
   // Bị phá: thân nến đóng vượt mép xa của dải thêm tol (râu xuyên qua không tính)
   bool broken = z.isRes ? b.close > z.hi + tol : b.close < z.lo - tol;
   if(broken)
     {
      if(z.flips == 0)
        {
         z.isRes = !z.isRes;
         z.flips = 1;
         z.flipTime = b.time + PeriodSeconds(PERIOD_M5);
         z.bouncesBeforeFlip = z.bounces;
         z.bounces = 0;
         z.touches = 0;
         // [GỐC] đúng chữ: sau lật phải rời >= awayAtr × biến động rồi mới tính chạm;
         // biến thể "chạm ngay" (code bản 1, Rare SnR): coi nến phá là đã rời vùng; [ỨNG VIÊN]: rời >= retestAwayAtrM5 × ATR(M5)
         z.away = !r.flipNeedsAway && r.retestAwayAtrM5 <= 0.0;
         z.inTouch = false;
         z.barsInside = 0;
         z.barsSinceFlip = 0;
         return ev | ZEV_FLIP;
        }
      z.dead = true;
      return ev | ZEV_DEAD;
     }
   // [ỨNG VIÊN] lật thất bại: trong vài nến sau lật có nến đóng quay lại trong dải
   if(r.failedFlipBars > 0 && z.flips == 1 && !z.flipFailed && z.barsSinceFlip <= r.failedFlipBars
      && b.close >= z.lo && b.close <= z.hi)
     {
      z.flipFailed = true;
      ev |= ZEV_FLIP_FAILED;
     }
   bool inside = b.high >= z.lo && b.low <= z.hi;
   if(inside)
     {
      z.barsInside++;
      bool gapOk = r.minTouchGapBars <= 0 || z.lastTouch == 0
                   || b.time - z.lastTouch >= r.minTouchGapBars * PeriodSeconds(PERIOD_M5);
      bool waitOk = z.flips == 0 || z.touches > 0 || z.barsSinceFlip >= r.retestMinBars;
      if(z.away && !z.inTouch && gapOk && waitOk)
        {
         z.touches++;
         z.lastTouch = b.time;
         z.away = false;
         z.inTouch = true;
         ev |= ZEV_TOUCH;
         // chạm lần đầu khi vùng đang "mới", râu vào dải và giá mở nằm ngoài dải về phía giá đi tới.
         // Mở sai phía vẫn là một lần chạm nhưng không phải "lần chạm đầu" để vào lệnh.
         bool openOk = z.isRes ? b.open < z.lo : b.open > z.hi;
         if(z.touches == 1 && openOk)
            ev |= ZEV_FIRST_TOUCH;
        }
     }
   else
      z.barsInside = 0;
   // Bật thật: đang trong một lần chạm (kể cả chính nến chạm), nến đóng ra ngoài dải về phía cũ. Mỗi lần chạm tối đa 1 lần bật.
   if(z.inTouch && (z.isRes ? b.close < z.lo : b.close > z.hi))
     {
      z.bounces++;
      z.inTouch = false;
      ev |= ZEV_BOUNCE;
     }
   // Rời xa: đo từ mép gần của dải bằng giá đóng cửa
   if(!z.inTouch && !z.away)
     {
      double need = r.awayAtr * z.atr;
      if(z.flips == 1 && z.touches == 0 && r.retestAwayAtrM5 > 0.0)
         need = r.retestAwayAtrM5 * atrM5;
      if(z.isRes ? b.close <= z.lo - need : b.close >= z.hi + need)
         z.away = true;
     }
   return ev;
  }

// Điểm sức mạnh [GỐC – giả định]. others = danh sách vùng thật; hợp lưu đếm mọi vùng thật khác còn sống
// có đường mức cách <= 0,3 × ATR(M15), tối đa 3. prevDayStart: lúc bắt đầu ngày hiện tại (chỉ đỉnh/đáy của đúng hôm qua được +2).
int ZoneScore(const Zone &z, const Zone &others[], int n, double atrM15, datetime prevDayStart)
  {
   int s = 0;
   switch(z.tf)
     {
      case PERIOD_M15: s += 1; break;
      case PERIOD_H1:  s += 2; break;
      case PERIOD_H4:  s += 3; break;
      default:         s += z.created >= prevDayStart ? 2 : 0; break;   // đỉnh/đáy ngày hôm trước
     }
   if(z.touches == 0)
      s += 2;                           // còn mới
   else if(z.touches >= 2)
      s -= 1;
   if(z.flips == 1 && z.touches == 0)
      s += 1;                           // vừa lật vai, còn mới
   if(z.strongOrigin)
      s += 1;
   int conf = 0;
   for(int j = 0; j < n && conf < 3; j++)
      if(others[j].id != z.id && !others[j].dead
         && MathAbs(others[j].level - z.level) <= 0.3 * atrM15)
         conf++;
   return s + conf;
  }

class CZones
  {
private:
   string            m_sym;
   ZoneRules         m_rules;
   ENUM_TIMEFRAMES   m_tfs[ZONE_TF_COUNT];
   int               m_atr[ZONE_TF_COUNT];
   int               m_atrM5;
   datetime          m_lastBar[ZONE_TF_COUNT];   // giờ mở của nến khung đang chạy ở lần Step trước
   int               m_nextId;
   datetime          m_dayStart;
   bool              m_weekendTrading;   // sàn mở cả thứ Bảy (BTC, ETH): ngày cuối tuần là ngày giao dịch thật

   static double     Body(const MqlRates &r) { return MathAbs(r.close - r.open); }
   static bool       Bull(const MqlRates &r) { return r.close > r.open; }
   static bool       Bear(const MqlRates &r) { return r.close < r.open; }

   // Giá trị chỉ báo của nến khung tf đã đóng gần nhất tính tới thời điểm t (không dùng nến đang chạy)
   double            BufAt(int handle, ENUM_TIMEFRAMES tf, datetime t)
     {
      int ps = PeriodSeconds(tf);
      double b[];
      if(CopyBuffer(handle, 0, (datetime)((long)t / ps * ps) - 1, 1, b) != 1)
         return 0.0;
      return b[0];
     }
   bool              Duplicate(ENUM_TIMEFRAMES tf, ENUM_ZONE_KIND kind, double level, double atr)
     {
      for(int i = 0; i < count; i++)
         if(!zones[i].dead && zones[i].tf == tf && zones[i].kind == kind && MathAbs(zones[i].level - level) < 0.1 * atr)
            return true;
      return false;
     }
   void              Add(ENUM_TIMEFRAMES tf, ENUM_ZONE_KIND kind, bool isRes, double level, double lo, double hi,
                         double atr, datetime created, bool strongOrigin)
     {
      if(atr <= 0.0 || Duplicate(tf, kind, level, atr))
         return;
      Zone z;
      z.id = m_nextId++;
      z.parent = -1;
      z.level = level;
      z.lo = lo;
      z.hi = hi;
      z.isRes = isRes;
      z.tf = tf;
      z.kind = kind;
      z.atr = atr;
      z.created = created;
      z.flipTime = 0;
      z.flips = 0;
      z.flipFailed = false;
      z.touches = 0;
      z.bounces = 0;
      z.bouncesBeforeFlip = 0;
      z.away = false;
      z.inTouch = false;
      z.lastTouch = 0;
      z.barsSinceFlip = 0;
      z.barsAlive = 0;
      z.copy = 0;
      z.barsInside = 0;
      z.strongOrigin = strongOrigin;
      z.dead = false;
      z.score = 0;
      ArrayResize(zones, count + 1, 64);
      zones[count++] = z;
      ArrayResize(newZones, newCount + 1, 16);
      newZones[newCount++] = z;
     }

   // r: chuỗi đảo, r[0] = nến khung vừa đóng (nến xác nhận). atr = ATR của nến xác nhận, giữ cố định suốt đời vùng.
   // Mức A/V: đỉnh/đáy xoay trên giá đóng cửa ở nến 3, xác nhận khi nến thứ 3 sau đỉnh đóng.
   void              DetectAV(const MqlRates &r[], double atr, ENUM_TIMEFRAMES tf, datetime created)
     {
      const int R = 3, k = 3;
      if(k + R >= ArraySize(r))
         return;
      bool isHigh = true, isLow = true;
      for(int j = 1; j <= R; j++)
        {
         if(r[k + j].close > r[k].close || r[k - j].close >= r[k].close)
            isHigh = false;
         if(r[k + j].close < r[k].close || r[k - j].close <= r[k].close)
            isLow = false;
        }
      bool strong = false;
      for(int j = k - 1; j <= k + 1; j++)
         if(Body(r[j]) >= 1.5 * atr)
            strong = true;
      if(isHigh)
        {
         // trong 2 nến quanh đỉnh: cặp "nến tăng rồi nến giảm" có giá đóng cao nhất; mức = giá đóng nến tăng
         double level = -1.0, wick = 0.0;
         for(int i = k - 1; i <= k + 2; i++)
            if(Bull(r[i]) && Bear(r[i - 1]) && r[i].close > level)
              {
               level = r[i].close;
               wick = MathMax(r[i].high, r[i - 1].high);
              }
         if(level < 0.0)
           {
            level = r[k].close;
            wick = r[k].high;
           }
         // dải từ mức tới đầu râu cao nhất của cặp, tối đa 0,5 × biến động
         Add(tf, ZK_AV, true, level, level, MathMin(wick, level + 0.5 * atr), atr, created, strong);
        }
      if(isLow)
        {
         double level = DBL_MAX, wick = 0.0;
         for(int i = k - 1; i <= k + 2; i++)
            if(Bear(r[i]) && Bull(r[i - 1]) && r[i].close < level)
              {
               level = r[i].close;
               wick = MathMin(r[i].low, r[i - 1].low);
              }
         if(level == DBL_MAX)
           {
            level = r[k].close;
            wick = r[k].low;
           }
         Add(tf, ZK_AV, false, level, MathMax(wick, level - 0.5 * atr), level, atr, created, strong);
        }
     }

   // Mức Gap: c1 = r[1], c2 = r[0] cùng màu; mức = giá đóng c1; dải theo khuôn A/V: từ mức tới râu của c2, tối đa 0,5 × biến động.
   void              DetectGap(const MqlRates &r[], double atr, ENUM_TIMEFRAMES tf, datetime created)
     {
      if(ArraySize(r) < 2)
         return;
      const MqlRates c1 = r[1];
      const MqlRates c2 = r[0];
      bool ok = m_rules.gapBaseBreakout
                ? Body(c1) <= 0.3 * atr && Body(c2) >= 3.0 * Body(c1) && Body(c2) >= 0.5 * atr
                : Body(c1) >= 0.5 * atr || Body(c2) >= 1.0 * atr;
      if(!ok)
         return;
      bool strong = Body(c1) >= 1.5 * atr || Body(c2) >= 1.5 * atr;
      double level = c1.close;
      if(Bull(c1) && Bull(c2))
         Add(tf, ZK_GAP, false, level, MathMin(level, MathMax(c2.low, level - 0.5 * atr)), level, atr, created, strong);
      else if(Bear(c1) && Bear(c2))
         Add(tf, ZK_GAP, true, level, level, MathMax(level, MathMin(c2.high, level + 0.5 * atr)), atr, created, strong);
     }

   // Đỉnh/đáy xoay trên giá cao/thấp nhất ở nến 5, 5 nến mỗi bên; dải = mức ± 0,15 × biến động
   void              DetectSwing(const MqlRates &r[], double atr, ENUM_TIMEFRAMES tf, datetime created)
     {
      const int R = 5, k = 5;
      if(k + R >= ArraySize(r))
         return;
      bool isHigh = true, isLow = true;
      for(int j = 1; j <= R; j++)
        {
         if(r[k + j].high > r[k].high || r[k - j].high >= r[k].high)
            isHigh = false;
         if(r[k + j].low < r[k].low || r[k - j].low <= r[k].low)
            isLow = false;
        }
      double band = 0.15 * atr;
      if(isHigh)
         Add(tf, ZK_SWING, true, r[k].high, r[k].high - band, r[k].high + band, atr, created, false);
      if(isLow)
         Add(tf, ZK_SWING, false, r[k].low, r[k].low - band, r[k].low + band, atr, created, false);
     }

   // Đỉnh/đáy ngày hôm trước theo nến D1 của sàn; bỏ nến ngày Chủ nhật/thứ Bảy (nến ngắn), trừ ký hiệu giao dịch cả cuối tuần.
   // Dải = mức ± 0,15 × ATR(D1). Tạo lúc nến D1 mới mở (dayOpen).
   void              DetectPrevDay(datetime dayOpen)
     {
      MqlRates d[];
      ArraySetAsSeries(d, true);
      int n = CopyRates(m_sym, PERIOD_D1, dayOpen - 1, 3, d);
      int k = -1;
      for(int i = 0; i < n && k < 0; i++)
        {
         MqlDateTime t;
         TimeToStruct(d[i].time, t);
         if(m_weekendTrading || (t.day_of_week != 0 && t.day_of_week != 6))
            k = i;
        }
      double atr = BufAt(m_atr[3], PERIOD_D1, dayOpen);
      if(k < 0 || atr <= 0.0)
        {
         loadErrors++;
         return;
        }
      double band = 0.15 * atr;
      Add(PERIOD_D1, ZK_PREVDAY, true, d[k].high, d[k].high - band, d[k].high + band, atr, dayOpen, false);
      Add(PERIOD_D1, ZK_PREVDAY, false, d[k].low, d[k].low - band, d[k].low + band, atr, dayOpen, false);
     }

   // Tìm vùng mới của khung t khi nến khung mở lúc barOpen vừa bắt đầu (nến trước nó vừa đóng).
   void              Detect(int t, datetime barOpen)
     {
      ENUM_TIMEFRAMES tf = m_tfs[t];
      if(tf == PERIOD_D1)
        {
         DetectPrevDay(barOpen);
         return;
        }
      const int need = 12;
      MqlRates r[];
      double a[];
      ArraySetAsSeries(r, true);
      ArraySetAsSeries(a, true);
      if(CopyRates(m_sym, tf, barOpen - 1, need, r) != need || CopyBuffer(m_atr[t], 0, barOpen - 1, 1, a) != 1)
        {
         loadErrors++;
         return;
        }
      datetime created = r[0].time + PeriodSeconds(tf);
      DetectAV(r, a[0], tf, created);
      DetectGap(r, a[0], tf, created);
      if(tf != PERIOD_H4)
         DetectSwing(r, a[0], tf, created);
     }

   // Xóa vùng: bị phá lần hai, quá xa giá, hết hạn [ỨNG VIÊN]; giữ tối đa maxPerTf vùng mỗi khung (bỏ vùng tạo sớm nhất).
   void              Prune(double price, datetime now, double atrH1)
     {
      int keep = 0;
      for(int i = 0; i < count; i++)
        {
         bool far = atrH1 > 0.0 && MathAbs(zones[i].level - price) > m_rules.farAtrH1 * atrH1;
         bool expired = ZoneExpired(zones[i], now, m_rules);
         if(far)
            droppedFar++;
         if(expired)
            droppedExpired++;
         if(zones[i].dead || far || expired)
            continue;
         if(keep != i)
            zones[keep] = zones[i];
         keep++;
        }
      count = keep;
      for(int t = 0; t < ZONE_TF_COUNT; t++)
        {
         int n = 0;
         for(int i = 0; i < count; i++)
            if(zones[i].tf == m_tfs[t])
               n++;
         while(n > m_rules.maxPerTf)
           {
            int oldest = -1;
            for(int i = 0; i < count; i++)
               if(zones[i].tf == m_tfs[t] && (oldest < 0 || zones[i].created < zones[oldest].created))
                  oldest = i;
            droppedCap++;
            if(zones[oldest].touches == 0)
               droppedCapFresh++;
            for(int i = oldest; i < count - 1; i++)
               zones[i] = zones[i + 1];
            count--;
            n--;
           }
        }
      ArrayResize(zones, count, 64);
     }

public:
   void              RefreshScores(datetime now)
     {
      double atr15 = BufAt(m_atr[0], PERIOD_M15, now);
      for(int i = 0; i < count; i++)
         zones[i].score = ZoneScore(zones[i], zones, count, atr15, m_dayStart);
     }

   // Một bước: nến M5 mở lúc now vừa bắt đầu, nến M5 trước đó vừa đóng.
   void              Step(datetime now, double swingLowM5, double swingHighM5, int strongScore, bool collect)
     {
      newCount = 0;
      ArrayResize(newZones, 0);
      evCount = 0;
      for(int t = 0; t < ZONE_TF_COUNT; t++)
        {
         int ps = PeriodSeconds(m_tfs[t]);
         datetime open = (datetime)((long)now / ps * ps);
         if(open != m_lastBar[t])
           {
            // Vàng: nến ngày thứ Bảy/Chủ nhật (sàn mở tối Chủ nhật) không phải ngày giao dịch: không tạo vùng ngày, không đổi mốc
            // "hôm nay"; tới 00:00 thứ Hai mới tạo đỉnh/đáy thứ Sáu, để suốt thứ Hai chúng đúng là "hôm qua".
            // Ký hiệu giao dịch cả cuối tuần (BTC, ETH): mọi ngày đều là ngày giao dịch.
            MqlDateTime od;
            TimeToStruct(open, od);
            bool weekend = m_tfs[t] == PERIOD_D1 && !m_weekendTrading && (od.day_of_week == 0 || od.day_of_week == 6);
            if(m_lastBar[t] != 0 && !weekend)
               Detect(t, open);
            m_lastBar[t] = open;
            if(m_tfs[t] == PERIOD_D1 && !weekend)
               m_dayStart = open;
           }
        }
      MqlRates b[];
      if(CopyRates(m_sym, PERIOD_M5, now - 1, 1, b) != 1)
        {
         loadErrors++;
         return;
        }
      double atrM5 = BufAt(m_atrM5, PERIOD_M5, now);
      int recent = 3 * PeriodSeconds(PERIOD_M5);
      for(int i = 0; i < count; i++)
        {
         if(zones[i].dead || b[0].time < zones[i].created)
            continue;
         Zone before = zones[i];
         int ev = ZoneStep(zones[i], b[0], atrM5, m_rules);
         if(!collect)
            continue;
         bool strong = before.score >= strongScore && ZoneIsBarrier(before);
         if(strong && (ev & (ZEV_FLIP | ZEV_DEAD)) != 0)
           {
            lastBreakDir = before.isRes ? 1 : -1;
            lastBreakTime = b[0].time;
           }
         // bị đẩy lại tại cản mạnh (vừa chạm trong 3 nến) và phá đỉnh/đáy xoay M5 gần nhất
         // chỉ tính lần chạm của vai hiện tại (lần chạm trước khi lật là của vai cũ)
         bool wasInside = before.lastTouch > 0 && before.lastTouch >= before.flipTime && b[0].time - before.lastTouch <= recent;
         if(strong && wasInside && (ev & (ZEV_FLIP | ZEV_DEAD)) == 0)
           {
            if(before.isRes && b[0].close < before.lo && swingLowM5 > 0.0 && b[0].close < swingLowM5)
              {
               lastRejectDir = -1;
               lastRejectTime = b[0].time;
              }
            if(!before.isRes && b[0].close > before.hi && swingHighM5 > 0.0 && b[0].close > swingHighM5)
              {
               lastRejectDir = 1;
               lastRejectTime = b[0].time;
              }
           }
         if(ev != 0)
           {
            ArrayResize(evZone, evCount + 1, 16);
            ArrayResize(evFlags, evCount + 1, 16);
            evZone[evCount] = zones[i];
            evZone[evCount].score = before.score;
            evFlags[evCount] = ev;
            evCount++;
           }
        }
      Prune(b[0].close, now, BufAt(m_atr[1], PERIOD_H1, now));
      if(collect)
         RefreshScores(now);
      lastStep = now;
     }

   Zone              zones[];
   int               count;
   Zone              newZones[];      // vùng mới tạo ở lần Step gần nhất
   int               newCount;
   Zone              evZone[];        // vùng có sự kiện ở nến vừa đóng (trạng thái sau nến, điểm = điểm trước nến)
   int               evFlags[];
   int               evCount;
   int               lastBreakDir;    // vùng mạnh vừa bị phá: 1 = phá lên, -1 = phá xuống
   datetime          lastBreakTime;
   int               lastRejectDir;   // bị đẩy lại tại cản mạnh và phá đỉnh/đáy xoay M5 gần nhất
   datetime          lastRejectTime;
   datetime          lastStep;
   int               loadErrors;      // số lần lấy nến/chỉ báo lỗi
   int               droppedCap;      // số vùng bị bỏ vì giới hạn mỗi khung
   int               droppedCapFresh; // trong đó vùng chưa bị chạm
   int               droppedFar;
   int               droppedExpired;

                     CZones(void) : count(0), newCount(0), evCount(0), m_nextId(0), m_dayStart(0),
                     lastBreakDir(0), lastBreakTime(0), lastRejectDir(0), lastRejectTime(0), lastStep(0),
                     loadErrors(0), droppedCap(0), droppedCapFresh(0), droppedFar(0), droppedExpired(0) {}

   bool              Init(const string sym, const ZoneRules &rules)
     {
      m_sym = sym;
      m_rules = rules;
      datetime sf, st;
      m_weekendTrading = SymbolInfoSessionTrade(sym, SATURDAY, 0, sf, st);
      m_tfs[0] = PERIOD_M15;
      m_tfs[1] = PERIOD_H1;
      m_tfs[2] = PERIOD_H4;
      m_tfs[3] = PERIOD_D1;
      for(int t = 0; t < ZONE_TF_COUNT; t++)
        {
         m_atr[t] = iATR(m_sym, m_tfs[t], 14);
         if(m_atr[t] == INVALID_HANDLE)
            return false;
         m_lastBar[t] = 0;
        }
      m_atrM5 = iATR(m_sym, PERIOD_M5, 14);
      return m_atrM5 != INVALID_HANDLE;
     }

   void              Release(void)
     {
      for(int t = 0; t < ZONE_TF_COUNT; t++)
         IndicatorRelease(m_atr[t]);
      IndicatorRelease(m_atrM5);
     }

   // Các chỉ báo ATR đã tính xong chưa (trong tester, lúc OnInit thường chưa có)
   bool              Ready(void)
     {
      for(int t = 0; t < ZONE_TF_COUNT; t++)
         if(BarsCalculated(m_atr[t]) <= 0)
            return false;
      return BarsCalculated(m_atrM5) > 0;
     }

   int               Id(void) const { return m_nextId; }
   double            AtrH1(datetime now) { return BufAt(m_atr[1], PERIOD_H1, now); }
   double            AtrM15(datetime now) { return BufAt(m_atr[0], PERIOD_M15, now); }
   datetime          DayStart(void) const { return m_dayStart; }

   // Bắt đầu lại từ đầu; nến M5 mở lúc firstBarOpen là mốc, các lần Step sau đi tiếp theo thời gian.
   void              Start(datetime firstBarOpen)
     {
      count = 0;
      ArrayResize(zones, 0);
      for(int t = 0; t < ZONE_TF_COUNT; t++)
        {
         int ps = PeriodSeconds(m_tfs[t]);
         m_lastBar[t] = (datetime)((long)firstBarOpen / ps * ps);
         if(m_tfs[t] == PERIOD_D1)
            m_dayStart = m_lastBar[t];
        }
     }

   // Nạp lịch sử: cho từng nến M5 trong warmupBars nến gần nhất chạy qua Step theo đúng thứ tự thời gian.
   // Trả về số nến đã chạy.
   int               Load(int warmupBars, int strongScore)
     {
      MqlRates m5[];
      int n = CopyRates(m_sym, PERIOD_M5, 0, warmupBars + 1, m5);
      if(n < 2)
         return 0;
      // m5[n-1] là nến đang chạy; mỗi nến i >= 1 mở lúc nến i-1 vừa đóng
      Start(m5[0].time);
      for(int i = 1; i < n; i++)
         Step(m5[i].time, 0.0, 0.0, strongScore, false);
      RefreshScores(m5[n - 1].time);
      newCount = 0;
      ArrayResize(newZones, 0);
      evCount = 0;
      return n - 1;
     }

   // Gọi khi nến M5 mới vừa mở (now = giờ mở của nó). swingLowM5/HighM5: đáy/đỉnh xoay M5 gần nhất (0 = không có).
   void              OnNewM5(datetime now, double swingLowM5, double swingHighM5, int strongScore)
     {
      // Bỏ sót nến (mất kết nối, không có tick): cho từng nến đã đóng chạy bù theo thứ tự, không gom tín hiệu,
      // rồi mới xét nến cuối. Trong tester nến nào cũng có tick nên không có nến nào phải chạy bù.
      if(lastStep > 0 && now - lastStep > PeriodSeconds(PERIOD_M5))
        {
         MqlRates r[];
         int n = CopyRates(m_sym, PERIOD_M5, lastStep, now - 1, r);
         for(int i = 0; i < n - 1; i++)
            Step(r[i].time + PeriodSeconds(PERIOD_M5), 0.0, 0.0, strongScore, false);
         if(n > 1)
            RefreshScores(r[n - 1].time);
        }
      Step(now, swingLowM5, swingHighM5, strongScore, true);
     }

   // Cản mạnh gần nhất phía trước theo chiều lệnh: dir = 1 tìm kháng cự phía trên, -1 tìm hỗ trợ phía dưới.
   // Chỉ tính vùng còn làm cản. Giá nằm trong dải → khoảng cách 0.
   int               NearestStrong(int dir, double price, int strongScore, double &dist)
     {
      int best = -1;
      dist = DBL_MAX;
      for(int i = 0; i < count; i++)
        {
         if(zones[i].isRes != (dir > 0) || zones[i].score < strongScore || !ZoneIsBarrier(zones[i]))
            continue;
         double d = dir > 0 ? zones[i].lo - price : price - zones[i].hi;
         if(price >= zones[i].lo && price <= zones[i].hi)
            d = 0.0;
         if(d < 0.0 || d >= dist)
            continue;
         dist = d;
         best = i;
        }
      return best;
     }

   bool              InsideStrong(double price, int strongScore)
     {
      for(int i = 0; i < count; i++)
         if(ZoneIsBarrier(zones[i]) && zones[i].score >= strongScore && price >= zones[i].lo && price <= zones[i].hi)
            return true;
      return false;
     }

   static string     KindName(const Zone &z)
     {
      if(z.kind == ZK_AV)
         return z.flips == 0 ? (z.isRes ? "A" : "V") : "A/V lật";
      if(z.kind == ZK_GAP)
         return z.flips == 0 ? "Gap" : "Gap lật";
      if(z.kind == ZK_SWING)
         return z.flips == 0 ? (z.isRes ? "Đỉnh" : "Đáy") : "Đỉnh/đáy lật";
      return z.flips == 0 ? (z.isRes ? "Đỉnh ngày" : "Đáy ngày") : "Đỉnh/đáy ngày lật";
     }
  };

#endif
