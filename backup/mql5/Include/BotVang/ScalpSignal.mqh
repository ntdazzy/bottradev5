// Luật scalping M1: M1 chọn vùng/điểm vào, H1 chọn chiều, khung lớn làm bối cảnh/cản. Không gửi lệnh.
#ifndef BOTVANG_SCALPSIGNAL_MQH
#define BOTVANG_SCALPSIGNAL_MQH

#include "HtfZones.mqh"

enum ENUM_SCALP_ENTRY { SCALP_MARKET = 0, SCALP_LIMIT = 1, SCALP_AUTO = 2 };
#define SCALP_MAX_RISK_ATR 3.0

struct ScalpSignal
  {
   bool              valid, early, htf;
   int               dir, reaction, zoneId, zoneType, zoneTf, biasH1, biasH4, biasD1;
   datetime          bar, known, touch;
   double            top, bottom, base, atr, rsi, activity;
  };

struct ScalpPlan
  {
   bool              limit;
   double            entry, sl, tp, obstacle, ratio;
   datetime          targetKnown;
   string            targetName, targetIssue;
   int               contextInside;
  };

// RSI Wilder; hoạt động = tick_volume nến vừa đóng / trung bình 20 nến TRƯỚC nó.
class CScalpForce
  {
private:
   double            m_gain, m_loss, m_close, m_vol[20], m_sum;
   int               m_count, m_volCount, m_pos;
   static double     Value(double up, double down)
     {
      if(up + down == 0.0) return 50.0;
      if(down == 0.0) return 100.0;
      return 100.0 - 100.0 / (1.0 + up / down);
     }
public:
   double            rsi, previous, activity;
   void              Init(void)
     {
      m_gain = m_loss = m_close = m_sum = 0.0;
      m_count = m_volCount = m_pos = 0;
      rsi = previous = 50.0; activity = 0.0;
      ArrayInitialize(m_vol, 0.0);
     }
   bool              Ready(void) const { return m_count >= 15 && m_volCount == 20; }
   void              Add(const MqlRates &r)
     {
      previous = rsi;
      if(m_count > 0)
        {
         double d = r.close - m_close;
         if(m_count <= 14)
           {
            m_gain += MathMax(d, 0.0) / 14.0;
            m_loss += MathMax(-d, 0.0) / 14.0;
           }
         else
           {
            m_gain = (13.0 * m_gain + MathMax(d, 0.0)) / 14.0;
            m_loss = (13.0 * m_loss + MathMax(-d, 0.0)) / 14.0;
           }
        }
      rsi = Value(m_gain, m_loss);
      activity = m_volCount == 20 && m_sum > 0.0 ? (double)r.tick_volume / (m_sum / 20.0) : 0.0;
      m_sum += (double)r.tick_volume - m_vol[m_pos];
      m_vol[m_pos] = (double)r.tick_volume;
      m_pos = (m_pos + 1) % 20;
      m_volCount = MathMin(20, m_volCount + 1);
      m_close = r.close; m_count++;
     }
   double            AtPrice(double price) const
     {
      double d = price - m_close;
      return Value((13.0 * m_gain + MathMax(d, 0.0)) / 14.0,
                   (13.0 * m_loss + MathMax(-d, 0.0)) / 14.0);
     }
  };

bool ScalpLongWick(int dir, const SmcBar &b, double atr)
  {
   double span = b.h - b.l;
   double location = dir > 0 ? b.c - b.l : b.h - b.c;
   return atr > 0.0 && span > 0.0 && ZWick(dir, b) >= 2.0 * ZBody(b)
          && ZWick(dir, b) >= 0.5 * atr && location / span >= 2.0 / 3.0;
  }

// RSI/hoạt động giá ghi để đối chiếu, không phủ quyết một phản ứng giá đã xác nhận.
bool ScalpPriceConfirmed(int dir, const SmcBar &previous, const SmcBar &b)
  {
   double span = b.h - b.l;
   if(span <= 0.0 || !(dir > 0 ? b.c > previous.h : b.c < previous.l)) return false;
   double location = dir > 0 ? b.c - b.l : b.h - b.c;
   return location / span >= 2.0 / 3.0 && (dir * (b.c - b.o) > 0.0 || ScalpLongWick(dir, b, b.atr));
  }

bool ScalpBiasAllowed(int dir, int h1) { return h1 != 0 && dir == h1; }

// Giá vào/thoát đúng phía đã chứa chênh lệch. Chỉ cộng đệm trượt một lần mỗi chặng.
double ScalpNetRatio(int dir, double entry, double sl, double tp, double slip)
  {
   double risk = dir * (entry - sl), reward = dir * (tp - entry) - slip;
   return risk > 0.0 && reward > 0.0 ? reward / (risk + 2.0 * slip) : 0.0;
  }

// Giá mua tối đa / giá bán tối thiểu còn đạt tỷ lệ sau đệm trượt. Không ép hồi 50% thân.
double ScalpEntryBoundary(int dir, double sl, double tp, double slip, double ratio)
  {
   return (tp + ratio * sl - dir * (1.0 + 2.0 * ratio) * slip) / (1.0 + ratio);
  }

bool ScalpRearm(SmcZone &z, const SmcBar &b, int i)
  {
   // Cần một nến nằm HOÀN TOÀN ngoài vùng, sau cửa sổ phản ứng cũ. Không đếm dao động trong vùng là lần chạm mới.
   if(z.k0 == -1 || i <= z.k0 + 1 || !(z.dir > 0 ? b.l > z.top : b.h < z.bottom)) return false;
   z.k0 = -1; z.fired = 0; z.m1Touched = false;
   return true;
  }

// Đỉnh/đáy 2/2 đã được xác nhận; chỉ dùng cực trị hình thành từ sau lúc khớp.
double ScalpMicroSwing(const CSmcBars &bars, int dir, datetime after)
  {
   for(int p = bars.n - 3; p >= 2 && bars.b[p].t >= after; p--)
      if(dir > 0 ? HtfPivotLow(bars, p, 2) : HtfPivotHigh(bars, p, 2))
         return dir > 0 ? bars.b[p].l : bars.b[p].h;
   return 0.0;
  }

bool ScalpStrongReverse(int dir, const SmcBar &previous, const SmcBar &b, bool atObstacle, double guard, bool fullPrevious = true)
  {
   bool broken = guard > 0.0 && (dir > 0 ? b.c < guard : b.c > guard);
   if(broken && dir * (b.c - b.o) < 0.0) return true;
   double span = b.h - b.l;
   double location = dir > 0 ? b.h - b.c : b.c - b.l;
   bool impulse = span > 0.0 && location / span >= 2.0 / 3.0 && -dir * (b.c - b.o) >= 0.8 * b.atr;
   if(impulse && fullPrevious && EngulfShape(-dir, previous, b)) return true;
   return atObstacle && ScalpLongWick(-dir, b, b.atr) && dir * (b.c - b.o) < 0.0;
  }

bool ScalpTightens(int dir, double oldSl, double newSl, double exitPrice, double minDist)
  {
   return newSl > 0.0 && dir * (newSl - oldSl) > 0.0 && dir * (exitPrice - newSl) > minDist;
  }

bool ScalpZoneExpired(const SmcZone &z, int bar)
  {
   int age = bar - z.born;
   return (z.type == ZT_MSNR && age >= 100) || (z.type == ZT_OB && age > 300)
          || ((z.type == ZT_FVG || z.type == ZT_SNR) && age > 500);
  }

bool ScalpGap(datetime previousTick, datetime currentTick, int period)
  {
   return previousTick > 0 && currentTick - previousTick >= period;
  }

class CScalpContext
  {
private:
   CSmcStructure     m_small, m_big;
   CSmcFvgs          m_fvg;
   int               m_period;
   int               m_usedId;
   bool              m_usedHtf;
   datetime          m_usedBar;

   void              FillSignal(ScalpSignal &s, const SmcZone &z, int reaction, bool fromHtf, int tf,
                                datetime known, const SmcBar &b, double base, bool early)
     {
      ZeroMemory(s);
      s.valid = true; s.early = early; s.htf = fromHtf;
      s.dir = z.dir; s.reaction = reaction; s.zoneId = z.id; s.zoneType = z.type; s.zoneTf = tf;
      s.bar = b.t; s.known = known; s.top = z.top; s.bottom = z.bottom; s.base = base; s.atr = b.atr;
      s.rsi = early ? force.AtPrice(b.c) : force.rsi;
      s.activity = force.activity;
      s.touch = early || z.k0 < 0 ? b.t : bars.b[z.k0].t;
      s.biasH1 = htf.T[1].st.trend; s.biasH4 = htf.T[2].st.trend; s.biasD1 = htf.T[3].st.trend;
     }

   // Không bỏ qua cản gần. Cản chứa giá hiện tại => room = 0, kế hoạch bị loại.
   void              Consider(int dir, double bid, double bottom, double top, datetime known, string name,
                              double &distance, ScalpPlan &p)
     {
      if(dir > 0 ? top < bid : bottom > bid) return;
      double edge = dir > 0 ? bottom : top;
      double d = MathMax(0.0, dir * (edge - bid));
      if(d >= distance) return;
      distance = d; p.obstacle = edge; p.targetKnown = known; p.targetName = name;
     }

public:
   CSmcBars          bars;
   CSmcZones         zones;
   CHtfZones         htf;
   CScalpForce       force;
   int               rearmed, biasBlocked;
   void              Init(void)
     {
      bars.Init(); zones.Init(); htf.Init(); force.Init(); m_fvg.Init();
      m_small.Init(5); m_big.Init(20); m_period = PeriodSeconds(_Period); rearmed = biasBlocked = 0;
      m_usedId = -1; m_usedHtf = false; m_usedBar = 0;
      zones.tagger = GetPointer(htf);
     }

   void              Used(const ScalpSignal &s)
     {
      m_usedId = s.zoneId; m_usedHtf = s.htf; m_usedBar = s.bar;
      // Đánh dấu mọi phản ứng của đúng vùng. Không thay k0 vì nó là chỉ số trong dãy nến.
      if(s.htf)
        { for(int k = 0; k < htf.n; k++) if(htf.z[k].s.id == s.zoneId) htf.z[k].s.fired = 7; }
      else
        { for(int k = 0; k < zones.n; k++) if(zones.z[k].id == s.zoneId) zones.z[k].fired = 7; }
     }

   // Phản ứng xét bằng trạng thái vùng đầu nến. Htf.Sync được EA gọi sau bước này.
   void              Add(const MqlRates &r, ScalpSignal &s, bool mayRearm = true)
     {
      ZeroMemory(s);
      int i = bars.Add(r);
      m_fvg.OnBar(bars, i);
      SmcBreak a, b;
      m_small.OnBar(bars, i, a); m_big.OnBar(bars, i, b);
      force.Add(r);
      if(i < 1 || !force.Ready() || !bars.Ready())
        { zones.OnBar(bars, i, a, b, m_fvg); htf.OnBar(bars, i); return; }
      SmcBar k = bars.b[i];
      // Xét vùng M1 đã biết đầu nến, trước khi OnBar tạo vùng mới hoặc đánh dấu phản ứng.
      int order[3] = {ZR_R2, ZR_R1, ZR_R3};
      for(int rr = 0; rr < 3; rr++)
         for(int type = 0; type < ZT_EMA; type++)
            for(int x = 0; x < zones.n && !s.valid; x++)
              {
               SmcZone z = zones.z[x];
               int reaction = order[rr];
               if(z.type != type || z.born >= i || ScalpZoneExpired(z, i)) continue;
               datetime known = bars.b[z.born].t + m_period;
               if(known > k.t) continue;
               int touch = z.k0;
               if(touch == -1 && ZTouch(z, k)) touch = i;
               if((touch != i && touch != i - 1) || (z.fired & (1 << reaction)) != 0) continue;
               bool reacts = reaction == ZR_R2 ? IsR2(z, bars.b[i - 1], k) : (reaction == ZR_R1 ? IsR1(z, k) : IsR3(z, k));
               if(!reacts || !ScalpPriceConfirmed(z.dir, bars.b[i - 1], k)) continue;
               if(z.id == m_usedId && !m_usedHtf && k.t <= m_usedBar + m_period) continue;
               double base = z.dir > 0 ? k.l : k.h;
               if(reaction == ZR_R2) base = z.dir > 0 ? MathMin(base, bars.b[i - 1].l) : MathMax(base, bars.b[i - 1].h);
               z.k0 = touch;
               FillSignal(s, z, reaction, false, -1, known, k, base, false);
              }
      zones.OnBar(bars, i, a, b, m_fvg);
      htf.OnBar(bars, i);
      if(mayRearm)
         for(int x = 0; x < zones.n; x++)
            if(zones.z[x].type != ZT_EMA && (!s.valid || s.zoneId != zones.z[x].id)
               && ScalpRearm(zones.z[x], k, i)) rearmed++;
     }

   // Gọi sau htf.Sync: vùng phản ứng phải tồn tại đầu M1, hướng dùng H1 đã đóng tại lúc quyết định.
   void              ConfirmBias(ScalpSignal &s)
     {
      if(!s.valid) return;
      s.biasH1 = htf.T[1].st.trend; s.biasH4 = htf.T[2].st.trend; s.biasD1 = htf.T[3].st.trend;
      if(!ScalpBiasAllowed(s.dir, s.biasH1)) { s.valid = false; biasBlocked++; }
     }

   bool              Alive(bool isHtf, int id, int type, int dir, double top, double bottom) const
     {
      if(!isHtf && type == ZT_EMA) return true; // EMA đã đóng băng khi phản ứng, hết hạn theo lệnh chờ.
      if(isHtf)
        {
         for(int k = 0; k < htf.n; k++)
            if(htf.z[k].s.id == id && !htf.z[k].dead && htf.z[k].s.dir == dir) return true;
        }
      else
         for(int k = 0; k < zones.n; k++)
            if(zones.z[k].id == id && zones.z[k].dir == dir && !ScalpZoneExpired(zones.z[k], bars.n)
               && zones.z[k].top == top && zones.z[k].bottom == bottom) return true;
      return false;
     }

   bool              Early(const MqlRates &r, const MqlTick &tick, ScalpSignal &s)
     {
      ZeroMemory(s);
      if(!force.Ready() || bars.n == 0 || tick.time - r.time < m_period / 5) return false;
      SmcBar b; b.t = r.time; b.o = r.open; b.h = r.high; b.l = r.low; b.c = r.close;
      b.atr = bars.b[bars.n - 1].atr; b.jump = false;
      SmcBar previous = bars.b[bars.n - 1];
      int bias = htf.T[1].st.trend;
      bool buy = bias == 1 && ScalpLongWick(1, b, b.atr) && ScalpPriceConfirmed(1, previous, b);
      bool sell = bias == -1 && ScalpLongWick(-1, b, b.atr) && ScalpPriceConfirmed(-1, previous, b);
      if(!buy && !sell) return false; // loại nến không có phản ứng trước khi duyệt hàng trăm vùng
      for(int type = 0; type < ZT_EMA; type++)
         for(int k = 0; k < zones.n; k++)
           {
            SmcZone z = zones.z[k];
            if(z.type != type || ScalpZoneExpired(z, bars.n) || z.fired == 7) continue;
            datetime known = bars.b[z.born].t + m_period;
            if(z.id == m_usedId && !m_usedHtf && r.time <= m_usedBar + m_period) continue;
            if((z.dir > 0 ? !buy : !sell) || z.k0 != -1 || known > r.time || (z.dir > 0 ? b.o <= z.top : b.o >= z.bottom)) continue;
            if(!IsR1(z, b)) continue;
            FillSignal(s, z, ZR_R1, false, -1, known, b, z.dir > 0 ? b.l : b.h, true);
            return true;
           }
      return s.valid;
     }

   bool              Target(int dir, double entry, double spread, double atr, ScalpPlan &p)
     {
      p.obstacle = 0.0; p.targetName = ""; p.targetKnown = 0; p.targetIssue = ""; p.contextInside = 0;
      double bid = entry - (dir > 0 ? spread : 0.0), distance = DBL_MAX;
      for(int k = 0; k < zones.n; k++)
        {
         SmcZone z = zones.z[k];
         if(z.dir == dir || z.type == ZT_EMA || ScalpZoneExpired(z, bars.n)) continue;
         Consider(dir, bid, z.bottom, z.top, bars.b[z.born].t + m_period,
                  "khung vao " + HtfTypeName[z.type], distance, p);
        }
      if(distance == DBL_MAX) { p.targetIssue = "chua co can M1 doi dien"; return false; }
      if(distance <= 0.0) { p.targetIssue = "gia nam trong can M1 " + p.targetName; return false; }
      for(int k = 0; k < htf.n; k++)
        {
         HtfZone z = htf.z[k];
         if(z.dead || z.s.dir == dir) continue;
         // Vùng lớn chứa giá là bối cảnh, không phải một bức tường kín chặn mọi phản ứng M1 bên trong.
         // Mép cản lớn còn ở PHÍA TRƯỚC vẫn chặn mục tiêu nếu gần hơn cản M1.
         if(z.s.top > z.s.bottom && bid >= z.s.bottom && bid <= z.s.top) { p.contextInside++; continue; }
         Consider(dir, bid, z.s.bottom, z.s.top, z.known,
                  HtfTfName[z.tf] + " " + HtfTypeName[z.s.type], distance, p);
        }
      if(distance <= 0.0) { p.targetIssue = "gia dang cham mep can lon " + p.targetName; return false; }
      double buffer = MathMax(spread, 0.1 * atr);
      p.tp = p.obstacle - dir * buffer + (dir < 0 ? spread : 0.0);
      if(dir * (p.tp - entry) <= 0.0) { p.targetIssue = "can gan hon chenhlech/dem " + p.targetName; return false; }
      return true;
     }

   bool              Plan(const ScalpSignal &s, const MqlTick &t, ENUM_SCALP_ENTRY mode, double slip,
                          double minRatio, ScalpPlan &p, string &why)
     {
      ZeroMemory(p);
      if(!Alive(s.htf, s.zoneId, s.zoneType, s.dir, s.top, s.bottom)) { why = "vung da hong/lat"; return false; }
      if(!ScalpBiasAllowed(s.dir, htf.T[1].st.trend)) { why = "H1 chua ro/da doi huong"; return false; }
      double spread = t.ask - t.bid, market = s.dir > 0 ? t.ask : t.bid;
      if(s.atr <= 0.0) { why = "thieu dao dong M1"; return false; }
      double base = s.dir > 0 ? MathMin(s.base, s.bottom) : MathMax(s.base, s.top);
      p.sl = base - s.dir * MathMax(spread, 0.1 * s.atr) + (s.dir < 0 ? spread : 0.0);
      p.entry = market;
      if(!Target(s.dir, market, spread, s.atr, p)) { why = p.targetIssue; return false; }
      p.ratio = ScalpNetRatio(s.dir, market, p.sl, p.tp, slip);
      double maxRisk = SCALP_MAX_RISK_ATR * s.atr;
      if(mode != SCALP_LIMIT && p.ratio >= minRatio && s.dir * (market - p.sl) <= maxRisk) return true;
      if(mode == SCALP_MARKET) { why = "vao ngay: ty le thap/dung qua xa cho M1"; return false; }
      p.limit = true;
      double boundary = ScalpEntryBoundary(s.dir, p.sl, p.tp, slip, minRatio);
      double improve = MathMax(spread, 0.1 * s.atr);
      p.entry = s.dir > 0 ? MathMin(MathMin(boundary, p.sl + maxRisk), market - improve)
                          : MathMax(MathMax(boundary, p.sl - maxRisk), market + improve);
      double step = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      if(step <= 0.0) step = _Point;
      p.entry = s.dir > 0 ? MathFloor(p.entry / step) * step : MathCeil(p.entry / step) * step;
      double bidEntry = p.entry - (s.dir > 0 ? spread : 0.0);
      if(s.dir > 0 ? bidEntry < s.bottom : bidEntry > s.top)
        { why = "dung qua xa: gia cho roi ngoai vung"; return false; }
      if(s.dir * (market - p.entry) < MathMax(spread, _Point)) { why = "gia cho khong tot hon"; return false; }
      if(!Target(s.dir, p.entry, spread, s.atr, p)) { why = p.targetIssue; return false; }
      p.ratio = ScalpNetRatio(s.dir, p.entry, p.sl, p.tp, slip);
      if(p.ratio < minRatio) { why = "ty le sau chi phi thap"; return false; }
      if(s.dir > 0 ? t.bid <= p.sl : t.ask >= p.sl) { why = "gia da vuot dung lo"; return false; }
      return true;
     }

   // Gọi TRƯỚC Add của nến này: chỉ thấy cản đã biết ở đầu nến, tránh lấy cản do chính nến tạo.
   bool              HitsOpposite(int dir, const MqlRates &r) const
     {
      for(int k = 0; k < zones.n; k++)
        {
         SmcZone z = zones.z[k];
         if(z.dir != dir && z.type != ZT_EMA && !ScalpZoneExpired(z, bars.n) && r.high >= z.bottom && r.low <= z.top) return true;
        }
      for(int k = 0; k < htf.n; k++)
        {
         HtfZone z = htf.z[k];
         double edge = dir > 0 ? z.s.bottom : z.s.top;
         if(!z.dead && z.s.dir != dir && z.known <= r.time && r.high >= edge && r.low <= edge) return true;
        }
      return false;
     }
  };

#endif
