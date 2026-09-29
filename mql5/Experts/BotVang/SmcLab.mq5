// SmcLab: đo lợi thế 4 cách vào lệnh SMC (SPEC §21.3) so với đối chứng (SPEC §21.4). CHỈ ĐỂ ĐO trong Strategy Tester,
// "mọi tick theo tick thật". Khung đo = khung chạy tester (lần đo 2: M1, M5). Không đặt lệnh thật.
#property copyright "BotVang"
#property version   "1.00"
#property description "Đo lợi thế FVG / OB / quét thanh khoản / mô hình ICT so với đối chứng (SPEC §21). Chỉ để đo."

#include <BotVang/SmcDetect.mqh>
#include <BotVang/SmcSim.mqh>
#include <BotVang/LabStats.mqh>
#include <BotVang/LabRandom.mqh>
#include <BotVang/Stats.mqh>

input string   InpRunName = "smc";            // Tên lần chạy (thư mục kết quả)
input ulong    InpSeed = 1;                   // Hạt giống cho đối chứng ngẫu nhiên
input double   InpSlip = 0.5;                 // Đệm trượt (theo giá) cho mỗi chặng thị trường/lệnh dừng: vàng 0,5; BTC 25; ETH 2,3
input double   InpTpR = 2.0;                  // Chốt lời = số lần R (lần đo 2: 1; 1,5; 2)
input int      InpControls = 20;              // Số đối chứng ngẫu nhiên cho mỗi lệnh thật
input int      InpWarmBars = 1000;            // Số nến lịch sử nạp trước khi bắt đầu đo
input int      InpNInt = 5;                   // Pivot lớp nội bộ (N/N)
input int      InpNSwing = 20;                // Pivot lớp lớn (N/N)
input int      InpMaxHold = 500;              // Giữ lệnh tối đa (nến), quá thì đóng theo giá thị trường
input int      InpRctDays = 10;               // Đối chứng thời điểm: cùng giờ, lệch ngẫu nhiên 1..N ngày về sau
input int      InpVnOffset = 7;               // Giờ VN = giờ sàn + số giờ này
input datetime InpCutVn = D'2026.07.06';      // Mốc chia khám phá / kiểm tra (giờ VN)

#define CELL_FVG_INT    0
#define CELL_FVG_SW     1
#define CELL_OBCH_INT   2
#define CELL_OBCH_SW    3
#define CELL_OBBOS_INT  4
#define CELL_OBBOS_SW   5
#define CELL_QUET       6
#define CELL_ICT        7
#define CELL_COUNT      8

string   CellName[CELL_COUNT] = {"FVG noi bo", "FVG lop lon", "OB sau CHoCH noi bo", "OB sau CHoCH lop lon", "OB sau BOS noi bo",
                                 "OB sau BOS lop lon", "Quet thanh khoan", "ICT (quet-CHoCH-vung)"};

CSmcBars       g_bars;
CSmcStructure  g_st[2];         // 0 nội bộ, 1 lớp lớn
CSmcFvgs       g_fvg;
CSmcLiquidity  g_liq;
CSmcSim        g_sim;
CRng           g_rng;
bool           g_warm = false;
datetime       g_lastBar = 0;
int            g_arm = 0;        // số lần đặt lệnh thật
int            g_skipped = 0;    // lệnh thật không đặt được (giá đã vượt mức đặt)
// FVG chờ thêm 1 nến (FVG có nến giữa là nến phá, xuất hiện ở nến sau)
bool           g_fvgWait[2];
int            g_fvgWaitDir[2], g_fvgWaitLeg[2], g_fvgWaitBreak[2];
// cú quét gần nhất cho mô hình ICT
bool           g_sweepOk[2];     // [0] quét tăng (dir +1), [1] quét giảm
int            g_sweepBar[2];
double         g_sweepExt[2];
// mô hình ICT chờ thêm 1 nến như FVG (SPEC §21.3)
struct IctWait { bool on; int dir; int leg; int brk; double ext; bool ob; double obLo; double obHi; };
IctWait        g_ictWait;
// kho khoảng cách/độ cao (theo ATR) của lệnh thật để sinh đối chứng mức ngẫu nhiên
// d: giá đóng − giá vào; h: giá vào − SL; e: giá vào − mép hủy vùng; tp: bội số chốt lời
struct Pool { double d[]; double h[]; double e[]; double tp[]; };
Pool           g_pool[CELL_COUNT];
// xu hướng khung H1 để lọc chiều mua/bán (SPEC §21.3 lần đo 2)
#define EMA_N 200
CSmcBars       g_hBars;
CSmcStructure  g_hSt;            // pivot 5/5 trên H1
datetime       g_hLast = 0;      // giờ mở nến H1 đã đóng cuối cùng đã nạp
double         g_ema = 0.0, g_hClose = 0.0;
int            g_emaCnt = 0;
// hàng chờ đối chứng thời điểm ngẫu nhiên (due = giờ mở nến vào lệnh)
#define RCT_ATR_TOL 0.2   // ATR lúc vào đối chứng lệch không quá 20% so với lệnh thật (SPEC §21.4)
#define RCT_TRIES   10    // số lần rút ngày tối đa
struct RctJob { datetime due; int dir; double slAtr; double atr; int part; int tries; int arm; };
RctJob         g_rct[];
int            g_rctDrop = 0;       // hết số lần rút (sàn đóng, biến động khác)
int            g_rctDropPart = 0;   // ngày rút rơi sang phần dữ liệu khác
// thông tin mỗi lần đặt lệnh thật; trendDir/emaDir = chiều xu hướng H1 / phía EMA 200 H1 lúc đặt (0: chưa biết)
struct ArmInfo { int cell; int dir; datetime t; int order; int trendDir; int emaDir; };
ArmInfo        g_arms[];

int PartOf(datetime server) { return server + InpVnOffset * 3600 < InpCutVn ? 0 : 1; }
int DayOf(datetime server) { return YmdKey(VnDayStart(server, InpVnOffset), InpVnOffset); }

void PoolAdd(int cell, double d, double h, double e, double tpR)
  {
   int k = ArraySize(g_pool[cell].d);
   ArrayResize(g_pool[cell].d, k + 1, 1024);
   ArrayResize(g_pool[cell].h, k + 1, 1024);
   ArrayResize(g_pool[cell].e, k + 1, 1024);
   ArrayResize(g_pool[cell].tp, k + 1, 1024);
   g_pool[cell].d[k] = d;
   g_pool[cell].h[k] = h;
   g_pool[cell].e[k] = e;
   g_pool[cell].tp[k] = tpR;
  }

void AddArm(int cell, int dir, datetime t, int order)
  {
   int a = ArraySize(g_arms);
   ArrayResize(g_arms, a + 1, 4096);
   g_arms[a].cell = cell;
   g_arms[a].dir = dir;
   g_arms[a].t = t;
   g_arms[a].order = order;
   g_arms[a].trendDir = g_hSt.trend;
   g_arms[a].emaDir = g_emaCnt < EMA_N ? 0 : (g_hClose > g_ema ? 1 : (g_hClose < g_ema ? -1 : 0));
  }

// Nạp các nến H1 đã đóng tới giờ (lần đầu: InpWarmBars nến): cấu trúc pivot 5/5 và EMA 200 của giá đóng
void SyncH1(void)
  {
   datetime last = iTime(_Symbol, PERIOD_H1, 1);
   if(last == 0 || last <= g_hLast)
      return;
   MqlRates h[];
   ArraySetAsSeries(h, false);
   int got = g_hLast == 0 ? CopyRates(_Symbol, PERIOD_H1, 1, InpWarmBars, h) : CopyRates(_Symbol, PERIOD_H1, (datetime)(g_hLast + 1), last, h);
   for(int k = 0; k < got; k++)
     {
      if(h[k].time <= g_hLast || h[k].time > last)
         continue;
      int i = g_hBars.Add(h[k]);
      SmcBreak ev;
      g_hSt.OnBar(g_hBars, i, ev);
      if(g_emaCnt < EMA_N)
         g_ema = (g_ema * g_emaCnt + h[k].close) / (g_emaCnt + 1);   // hạt giống = trung bình EMA_N giá đóng đầu
      else
         g_ema += 2.0 / (EMA_N + 1) * (h[k].close - g_ema);
      g_emaCnt++;
      g_hClose = h[k].close;
      g_hLast = h[k].time;
     }
  }

// SL lần đo 2: mua = đáy lớn gần nhất có giá ≤ mốc cũ, trừ 0,1 ATR; không có thì mốc cũ − 0,1 ATR. Bán ngược lại.
double WideSl(int dir, double base, double atr)
  {
   double p = dir > 0 ? g_st[1].NearestLow(base) : g_st[1].NearestHigh(base);
   return (p != 0.0 ? p : base) - dir * 0.1 * atr;
  }

// Đặt một lệnh thật dạng giới hạn và các đối chứng mức ngẫu nhiên. Trả về false nếu giá đã vượt mức đặt.
bool ArmLimit(int cell, int dir, double entry, double sl, double tp, double zoneEdge, int layer, int maxBars, bool tpFirst,
              double closeRef, double atr, const MqlTick &t)
  {
   double risk = (entry - sl) * dir;
   if(risk <= 0.0 || (tp - entry) * dir <= 0.0 || atr <= 0.0)
      return false;
   if((dir > 0 && t.ask <= entry) || (dir < 0 && t.bid >= entry))
     {
      g_skipped++;
      return false;
     }
   VOrder v;
   ZeroMemory(v);
   v.cell = cell;
   v.kind = VK_REAL;
   v.arm = g_arm;
   v.dir = dir;
   v.market = false;
   v.entry = entry;
   v.sl = sl;
   v.tp = tp;
   v.zoneEdge = zoneEdge;
   v.layer = layer;
   v.maxBars = maxBars;
   v.tpFirst = tpFirst;
   AddArm(cell, dir, t.time, g_sim.Add(v, t));
   // đối chứng mức ngẫu nhiên: khoảng cách và độ cao rút từ các lệnh thật khác cùng ô đã có trước (không lấy chính lệnh này)
   int np = ArraySize(g_pool[cell].d);
   for(int k = 0; k < InpControls && np > 0; k++)
     {
      int j = g_rng.Below(np);
      double ce = closeRef - dir * g_pool[cell].d[j] * atr;
      double r = g_pool[cell].h[j] * atr;
      VOrder c;
      ZeroMemory(c);
      c.cell = cell;
      c.kind = VK_RCL;
      c.arm = g_arm;
      c.dir = dir;
      c.market = false;
      c.entry = ce;
      c.sl = ce - dir * r;
      c.tp = ce + dir * g_pool[cell].tp[j] * r;
      c.zoneEdge = ce - dir * g_pool[cell].e[j] * atr;
      c.layer = layer;
      c.maxBars = maxBars;
      c.tpFirst = tpFirst;
      if((dir > 0 && t.ask <= ce) || (dir < 0 && t.bid >= ce))
         continue;   // mức giả đã bị giá vượt: bỏ (giống lệnh thật)
      g_sim.Add(c, t);
     }
   PoolAdd(cell, (closeRef - entry) * dir / atr, risk / atr, (entry - zoneEdge) * dir / atr, (tp - entry) * dir / risk);
   g_arm++;
   return true;
  }

// Lệnh thật vào ngay (quét thanh khoản) và lịch đối chứng thời điểm ngẫu nhiên
void ArmMarket(int cell, int dir, double sl, double tpR, double atr, const MqlTick &t)
  {
   double entry = dir > 0 ? t.ask : t.bid;
   double risk = (entry - sl) * dir;
   if(risk <= 0.0 || atr <= 0.0)
      return;
   VOrder v;
   ZeroMemory(v);
   v.cell = cell;
   v.kind = VK_REAL;
   v.arm = g_arm;
   v.dir = dir;
   v.market = true;
   v.entry = entry;
   v.sl = sl;
   v.tp = entry + dir * tpR * risk;
   v.zoneEdge = 0.0;
   v.layer = -1;
   v.maxBars = 0;
   v.tpFirst = false;
   AddArm(cell, dir, t.time, g_sim.Add(v, t));
   for(int k = 0; k < InpControls; k++)
     {
      RctJob j;
      j.due = g_lastBar;   // giờ mở nến vào lệnh thật
      j.dir = dir;
      j.slAtr = risk / atr;
      j.atr = atr;
      j.part = PartOf(t.time);
      j.tries = 0;
      j.arm = g_arm;
      if(!RctDraw(j, g_lastBar))
         continue;
      int m = ArraySize(g_rct);
      ArrayResize(g_rct, m + 1, 1024);
      g_rct[m] = j;
     }
   g_arm++;
  }

// Rút ngày cho đối chứng thời điểm: cùng giờ mở nến, 1..InpRctDays ngày sau lần hẹn trước, sau nến barOpen.
// Trả về false (bỏ) khi hết số lần rút hoặc ngày rút rơi sang phần dữ liệu khác.
bool RctDraw(RctJob &j, datetime barOpen)
  {
   do
     {
      if(j.tries >= RCT_TRIES)
        {
         g_rctDrop++;
         return false;
        }
      j.tries++;
      j.due += (1 + g_rng.Below(InpRctDays)) * 86400;
     }
   while(j.due <= barOpen);
   if(PartOf(j.due) != j.part)
     {
      g_rctDropPart++;
      return false;
     }
   return true;
  }

// Đối chứng thời điểm ngẫu nhiên tới hạn ở nến mới này (mở lúc barOpen, atr = ATR nến vừa đóng)
void RunRct(datetime barOpen, double atr, const MqlTick &t)
  {
   int keep = 0;
   for(int k = 0; k < ArraySize(g_rct); k++)
     {
      RctJob j = g_rct[k];
      if(j.due > barOpen)
        {
         g_rct[keep++] = j;
         continue;
        }
      // không có nến đúng giờ hẹn (sàn đóng) hoặc biến động khác lệnh thật: rút ngày khác
      if(j.due < barOpen || MathAbs(atr / j.atr - 1.0) > RCT_ATR_TOL)
        {
         if(RctDraw(j, barOpen))
            g_rct[keep++] = j;
         continue;
        }
      double entry = j.dir > 0 ? t.ask : t.bid;
      double risk = j.slAtr * atr;
      VOrder c;
      ZeroMemory(c);
      c.cell = CELL_QUET;
      c.kind = VK_RCT;
      c.arm = j.arm;
      c.dir = j.dir;
      c.market = true;
      c.entry = entry;
      c.sl = entry - c.dir * risk;
      c.tp = entry + c.dir * InpTpR * risk;
      c.layer = -1;
      g_sim.Add(c, t);
     }
   ArrayResize(g_rct, keep, 1024);
  }

// Lệnh thật vừa khớp: sinh đối chứng đảo chiều (vào ngay, ngược chiều, cùng khoảng dừng lỗ và cùng bội số chốt lời)
void SpawnFlips(const MqlTick &t)
  {
   int count = g_sim.nJust;
   g_sim.nJust = 0;
   for(int q = 0; q < count; q++)
     {
      int k = g_sim.justFilled[q];
      if(g_sim.o[k].flipDone)
         continue;
      g_sim.o[k].flipDone = true;
      double risk = MathAbs(g_sim.o[k].entry - g_sim.o[k].sl);
      double tpR = MathAbs(g_sim.o[k].tp - g_sim.o[k].entry) / risk;
      int dir = -g_sim.o[k].dir;
      double entry = dir > 0 ? t.ask : t.bid;
      VOrder c;
      ZeroMemory(c);
      c.cell = g_sim.o[k].cell;
      c.kind = VK_RCD;
      c.arm = g_sim.o[k].arm;
      c.dir = dir;
      c.market = true;
      c.entry = entry;
      c.sl = entry - dir * risk;
      c.tp = entry + dir * tpR * risk;
      c.layer = -1;
      int idx = g_sim.Add(c, t);
      // phí như lệnh thật: lệnh thật giới hạn không trả đệm trượt lúc vào thì lệnh đảo chiều cũng không
      if(!g_sim.o[k].market)
         g_sim.o[idx].legs = 0;
     }
  }

// Một lớp cấu trúc vừa phá ở nến i: đặt các lệnh FVG và OB (SPEC §21.3)
void OnBreak(int layer, const SmcBreak &ev, const MqlTick &t)
  {
   if(ev.initial)
      return;
   int i = ev.i;
   double atr = g_bars.b[i].atr;
   double close = g_bars.b[i].c;
   int dir = ev.dir;
   // OB sau CHoCH / BOS
   if(ev.ob)
     {
      double entry = dir > 0 ? ev.obHi : ev.obLo;
      double edge = dir > 0 ? ev.obLo : ev.obHi;
      double sl = WideSl(dir, edge, atr);
      double tp = entry + dir * InpTpR * (entry - sl) * dir;
      int cell = ev.choch ? (layer == 0 ? CELL_OBCH_INT : CELL_OBCH_SW) : (layer == 0 ? CELL_OBBOS_INT : CELL_OBBOS_SW);
      ArmLimit(cell, dir, entry, sl, tp, edge, layer, 50, true, close, atr, t);
     }
   // FVG mới nhất trong cú phá (nến giữa nằm sau nến cực trị của chân, tới nến phá)
   if(ev.leg < 0)
      return;
   if(MaybeFvgMid(dir, i))
     {
      g_fvgWait[layer] = true;
      g_fvgWaitDir[layer] = dir;
      g_fvgWaitLeg[layer] = ev.leg;
      g_fvgWaitBreak[layer] = i;
      return;
     }
   int f = g_fvg.FindFresh(dir, ev.leg, i);
   if(f >= 0)
      ArmFvg(layer, f, close, t);
  }

// Nến i có thể là nến giữa của một FVG chiều dir (FVG đó chỉ xuất hiện lúc đóng nến i+1)
bool MaybeFvgMid(int dir, int i)
  {
   if(i < 1 || g_bars.b[i].jump)
      return false;
   return dir > 0 ? g_bars.b[i].c > g_bars.b[i - 1].h : g_bars.b[i].c < g_bars.b[i - 1].l;
  }

void ArmFvg(int layer, int f, double closeRef, const MqlTick &t)
  {
   SmcFvg z = g_fvg.f[f];
   int dir = z.dir;
   double entry = dir > 0 ? z.top : z.bottom;
   double edge = dir > 0 ? z.bottom : z.top;
   double sl = WideSl(dir, edge, z.atr);
   double tp = entry + dir * InpTpR * (entry - sl) * dir;
   ArmLimit(layer == 0 ? CELL_FVG_INT : CELL_FVG_SW, dir, entry, sl, tp, edge, layer, 30, true, closeRef, g_bars.b[g_bars.n - 1].atr, t);
  }

// Mô hình ICT: cú quét cùng chiều gần nhất trong 0..20 nến trước CHoCH nội bộ (tính cả nến CHoCH); vào ở FVG của cú đảo,
// không có thì OB. Chờ thêm 1 nến như FVG khi nến CHoCH có thể là nến giữa của FVG.
void TryIct(const SmcBreak &ev, const MqlTick &t)
  {
   if(ev.initial || !ev.choch || ev.leg < 0)
      return;
   int s = ev.dir > 0 ? 0 : 1;
   if(!g_sweepOk[s] || ev.i - g_sweepBar[s] > 20 || ev.i < g_sweepBar[s])
      return;
   g_sweepOk[s] = false;   // mỗi cú quét dùng một lần
   g_ictWait.dir = ev.dir;
   g_ictWait.leg = ev.leg;
   g_ictWait.brk = ev.i;
   g_ictWait.ext = g_sweepExt[s];
   g_ictWait.ob = ev.ob;
   g_ictWait.obLo = ev.obLo;
   g_ictWait.obHi = ev.obHi;
   g_ictWait.on = MaybeFvgMid(ev.dir, ev.i);
   if(!g_ictWait.on)
      ArmIct(ev.i, t);
  }

// Đặt lệnh ICT lúc đóng nến i (nến CHoCH hoặc nến sau nó) theo g_ictWait
void ArmIct(int i, const MqlTick &t)
  {
   IctWait w = g_ictWait;
   int dir = w.dir;
   double top, bottom;
   int f = g_fvg.FindFresh(dir, w.leg, w.brk);
   if(f >= 0)
     {
      top = g_fvg.f[f].top;
      bottom = g_fvg.f[f].bottom;
     }
   else
     {
      if(!w.ob)
         return;
      top = w.obHi;
      bottom = w.obLo;
      // nến chờ đã chạm hoặc đóng qua OB: OB không còn mới
      if(i > w.brk && (dir > 0 ? g_bars.b[i].l <= top || g_bars.b[i].c < bottom : g_bars.b[i].h >= bottom || g_bars.b[i].c > top))
         return;
     }
   double atr = g_bars.b[i].atr;
   double entry = dir > 0 ? top : bottom;
   double edge = dir > 0 ? bottom : top;
   double sl = WideSl(dir, w.ext, atr);
   double risk = (entry - sl) * dir;
   if(risk <= 0.0)
      return;
   double tp = entry + dir * InpTpR * risk;
   ArmLimit(CELL_ICT, dir, entry, sl, tp, edge, -1, 30, false, g_bars.b[i].c, atr, t);
  }

// Xử lý một nến đã đóng; trade = false khi đang nạp lịch sử
void ProcessBar(const MqlRates &r, bool trade, const MqlTick &t)
  {
   int i = g_bars.Add(r);
   g_sim.curBar = i;
   g_fvg.OnBar(g_bars, i);
   SmcSweep up, down;
   g_liq.OnBar(g_bars, i, up, down);
   SmcBreak ev[2];
   int opp[2];
   for(int L = 0; L < 2; L++)
     {
      g_st[L].OnBar(g_bars, i, ev[L]);
      opp[L] = ev[L].valid ? ev[L].dir : 0;
     }
   if(!trade || !g_bars.Ready())
      return;
   double atr = g_bars.b[i].atr;
   // hủy/đóng lệnh theo nến vừa đóng, rồi mới đặt lệnh mới
   g_sim.OnBar(i, r.close, opp, InpMaxHold, t);
   RunRct(g_lastBar, atr, t);
   // FVG chờ từ lần phá ở nến trước (nến này phá ngược chiều cùng lớp thì bỏ)
   for(int L = 0; L < 2; L++)
      if(g_fvgWait[L])
        {
         g_fvgWait[L] = false;
         if(i == g_fvgWaitBreak[L] + 1 && opp[L] != -g_fvgWaitDir[L])
           {
            int f = g_fvg.FindFresh(g_fvgWaitDir[L], g_fvgWaitLeg[L], g_fvgWaitBreak[L]);
            if(f >= 0)
               ArmFvg(L, f, r.close, t);
           }
        }
   // ICT chờ từ CHoCH ở nến trước (nến này phá ngược chiều lớp nội bộ thì bỏ)
   if(g_ictWait.on)
     {
      g_ictWait.on = false;
      if(i == g_ictWait.brk + 1 && opp[0] != -g_ictWait.dir)
         ArmIct(i, t);
     }
   // quét thanh khoản: lệnh vào ngay + ghi nhận cho mô hình ICT
   if(up.valid)
     {
      ArmMarket(CELL_QUET, 1, WideSl(1, up.extreme, atr), InpTpR, atr, t);
      g_sweepOk[0] = true;
      g_sweepBar[0] = i;
      g_sweepExt[0] = up.extreme;
     }
   if(down.valid)
     {
      ArmMarket(CELL_QUET, -1, WideSl(-1, down.extreme, atr), InpTpR, atr, t);
      g_sweepOk[1] = true;
      g_sweepBar[1] = i;
      g_sweepExt[1] = down.extreme;
     }
   for(int L = 0; L < 2; L++)
      if(ev[L].valid)
        {
         OnBreak(L, ev[L], t);
         if(L == 0)
            TryIct(ev[L], t);
        }
  }

int OnInit()
  {
   g_bars.Init();
   g_st[0].Init(InpNInt);
   g_st[1].Init(InpNSwing);
   g_fvg.Init();
   g_liq.Init(5);
   g_sim.Init();
   g_rng.Seed(RngMix(InpSeed, 0x5AC1AB));
   ArrayResize(g_arms, 0, 4096);
   ArrayResize(g_rct, 0, 1024);
   for(int L = 0; L < 2; L++)
      g_fvgWait[L] = false;
   g_sweepOk[0] = g_sweepOk[1] = false;
   g_ictWait.on = false;
   g_hBars.Init();
   g_hSt.Init(5);
   return INIT_SUCCEEDED;
  }

void OnTick()
  {
   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t))
      return;
   if(!g_warm)
     {
      // nạp lịch sử: các nến đã đóng trước nến hiện tại, không đặt lệnh
      MqlRates h[];
      ArraySetAsSeries(h, false);
      int got = CopyRates(_Symbol, _Period, 1, InpWarmBars, h);
      for(int k = 0; k < got; k++)
         ProcessBar(h[k], false, t);
      SyncH1();
      g_lastBar = iTime(_Symbol, _Period, 0);
      g_warm = true;
      PrintFormat("[SmcLab] nạp %d nến lịch sử, bắt đầu đo từ %s", got, TimeToString(g_lastBar));
     }
   datetime bar = iTime(_Symbol, _Period, 0);
   if(bar != g_lastBar && bar != 0)
     {
      g_lastBar = bar;
      SyncH1();   // nến H1 vừa đóng (nếu có) được nạp trước khi đặt lệnh ở nến này
      MqlRates r[];
      if(CopyRates(_Symbol, _Period, 1, 1, r) == 1)
         ProcessBar(r[0], true, t);
     }
   g_sim.OnTick(t);
   SpawnFlips(t);
  }

string Num(double v, int d = 3) { return (v >= 0 ? "+" : "") + DoubleToString(v, d); }

string CiText(CSamples &s, ulong seed)
  {
   double lo, hi;
   if(s.Days() < 20 || s.Count() < 30 || !s.CI(2000, seed, BootRank(2000, 0.05), lo, hi))
      return "[ít dữ liệu]";
   return "[" + Num(lo) + "; " + Num(hi) + "]";
  }

double OnTester()
  {
   MqlTick t;
   SymbolInfoTick(_Symbol, t);
   g_sim.Finish(t);
   string folder = "SmcLab\\" + InpRunName + "_" + _Symbol + "_" + StringSubstr(EnumToString(_Period), 7) + "\\";
   // file từng lệnh
   int h = FileOpen(folder + "lenh.csv", FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON, 0, CP_UTF8);
   if(h != INVALID_HANDLE)
     {
      FileWriteString(h, "arm;o;kieu;chieu;dat_luc;khop_luc;dong_luc;vao;sl;tp;ly_do;R0;Rc\r\n");
      for(int k = 0; k < g_sim.n; k++)
        {
         VOrder v = g_sim.o[k];
         bool filled = v.fillTime != 0 && v.reason != VX_END;
         FileWriteString(h, StringFormat("%d;%s;%d;%d;%s;%s;%s;%s;%s;%s;%d;%s;%s\r\n", v.arm, CellName[v.cell], v.kind, v.dir,
                         TimeToString(v.armTime, TIME_DATE | TIME_SECONDS), v.fillTime ? TimeToString(v.fillTime, TIME_DATE | TIME_SECONDS) : "",
                         TimeToString(v.exitTime, TIME_DATE | TIME_SECONDS), DoubleToString(v.fill ? v.fill : v.entry, _Digits),
                         DoubleToString(v.sl, _Digits), DoubleToString(v.tp, _Digits), v.reason,
                         filled ? DoubleToString(CSmcSim::R(v, 0.0), 3) : "", filled ? DoubleToString(CSmcSim::R(v, InpSlip), 3) : ""));
        }
      FileClose(h);
     }
   // gom đối chứng theo lần đặt: giá trị mỗi lần đặt = R sau phí nếu khớp và đã đóng, 0 nếu không khớp
   int na = g_arm;
   double ctrlSum[], rcdR[];
   int ctrlCnt[];
   bool bad[];
   ArrayResize(ctrlSum, na);
   ArrayResize(ctrlCnt, na);
   ArrayResize(rcdR, na);
   ArrayResize(bad, na);
   ArrayInitialize(ctrlSum, 0.0);
   ArrayInitialize(ctrlCnt, 0);
   ArrayInitialize(rcdR, EMPTY_VALUE);
   ArrayInitialize(bad, false);
   for(int k = 0; k < g_sim.n; k++)
     {
      VOrder v = g_sim.o[k];
      if(v.arm < 0 || v.arm >= na)
         continue;
      if(v.reason == VX_END || v.reason == VX_C_END)
        {
         if(v.kind == VK_REAL)
            bad[v.arm] = true;   // chưa xong khi hết dữ liệu: bỏ cả lần đặt
         continue;
        }
      double val = v.fillTime != 0 ? CSmcSim::R(v, InpSlip) : 0.0;
      if(v.kind == VK_RCL || (v.kind == VK_RCT && v.fillTime != 0))
        {
         ctrlSum[v.arm] += val;
         ctrlCnt[v.arm]++;
        }
      if(v.kind == VK_RCD && v.fillTime != 0)
         rcdR[v.arm] = val;
     }
   string lines[];
   int nl = 0;
   ArrayResize(lines, 200);
   lines[nl++] = StringFormat("%s %s %s: đệm trượt %s giá; %d đối chứng mỗi lệnh; lần đặt lệnh thật %d (bỏ %d vì giá đã vượt mức đặt); đối chứng thời điểm bỏ %d (hết %d lần rút: sàn đóng/biến động khác), %d (sang phần dữ liệu khác)",
                              InpRunName, _Symbol, EnumToString(_Period), DoubleToString(InpSlip, 2), InpControls, g_arm, g_skipped,
                              g_rctDrop + g_rctDropPart, RCT_TRIES, g_rctDropPart);
   lines[nl++] = StringFormat("Chốt lời %sR. Cột: chọn chiều | ô | phần | lần đặt | khớp (%%) | thắng (%%) | R TB lệnh khớp (sau phí) [KTC95] | thật − đối chứng ngẫu nhiên / lần đặt [KTC95] | thật − đảo chiều [KTC95] | kết luận",
                              DoubleToString(InpTpR, 1));
   string parts[2] = {"kham pha", "kiem tra"};
   // cách chọn mua/bán (SPEC §21.3 lần đo 2): mọi tín hiệu; chỉ lệnh cùng chiều xu hướng H1; chỉ lệnh cùng phía EMA 200 H1
   string modes[3] = {"tin hieu", "xu huong H1", "EMA200 H1"};
   for(int m = 0; m < 3; m++)
   for(int c = 0; c < CELL_COUNT; c++)
      for(int p = 0; p < 2; p++)
        {
         CSamples rFill, dCtrl, dFlip;
         int armed = 0, filled = 0, wins = 0;
         for(int a = 0; a < ArraySize(g_arms); a++)
           {
            if(g_arms[a].cell != c || PartOf(g_arms[a].t) != p || bad[a])
               continue;
            if((m == 1 && g_arms[a].trendDir != g_arms[a].dir) || (m == 2 && g_arms[a].emaDir != g_arms[a].dir))
               continue;
            armed++;
            VOrder v = g_sim.o[g_arms[a].order];
            int day = DayOf(g_arms[a].t);
            double real = 0.0;
            if(v.fillTime != 0)
              {
               filled++;
               real = CSmcSim::R(v, InpSlip);
               rFill.Add(day, real);
               if(real > 0.0)
                  wins++;
               if(rcdR[a] != EMPTY_VALUE)
                  dFlip.Add(day, real - rcdR[a]);
              }
            if(ctrlCnt[a] > 0)
              {
               // quét thanh khoản: so R lệnh thật với R trung bình đối chứng đã vào; các ô còn lại: so theo lần đặt (không khớp = 0)
               double base = c == CELL_QUET ? (v.fillTime != 0 ? real : 0.0) : real;
               dCtrl.Add(day, base - ctrlSum[a] / ctrlCnt[a]);
              }
           }
         if(armed == 0)
           {
            lines[nl++] = StringFormat("%-11s | %-24s | %-8s | 0", modes[m], CellName[c], parts[p]);
            continue;
           }
         ulong seed = RngMix(InpSeed, (ulong)(m * 100 + c * 10 + p));
         double lo = 0.0, hi = 0.0;
         bool ciOk = dCtrl.Days() >= 20 && dCtrl.Count() >= 30 && dCtrl.CI(2000, seed, BootRank(2000, 0.05), lo, hi);
         string ctrlCi = ciOk ? "[" + Num(lo) + "; " + Num(hi) + "]" : "[ít dữ liệu]";   // cùng khoảng dùng cho kết luận
         string verdict = filled < 100 ? "ít dữ liệu" : "";
         if(p == 0 && ciOk)
            verdict += (verdict != "" ? ", " : "") + (lo > 0.0 && rFill.Mean() > 0.0 ? "ĐẠT (khám phá)" : "KHÔNG ĐẠT");
         // phần kiểm tra (lần đo 2, SPEC §21.4): khoảng tin cậy cũng phải trên 0 mới đạt
         if(p == 1 && dCtrl.Count() > 0)
            verdict += (verdict != "" ? ", " : "") + (rFill.Mean() > 0.0 && ciOk && lo > 0.0 ? "ĐẠT (kiểm tra)" :
                        (dCtrl.Mean() > 0.0 && rFill.Mean() > 0.0 ? "cùng dấu dương, chưa chắc" : "không giữ được"));
         lines[nl++] = StringFormat("%-11s | %-24s | %-8s | %5d | %5d (%4.1f%%) | %4.1f%% | %s %s | %s %s | %s %s | %s", modes[m], CellName[c], parts[p], armed, filled,
                                    100.0 * filled / armed, filled > 0 ? 100.0 * wins / filled : 0.0,
                                    Num(rFill.Mean()), CiText(rFill, seed + 1), Num(dCtrl.Mean()), ctrlCi,
                                    Num(dFlip.Mean()), CiText(dFlip, seed + 3), verdict);
        }
   int fh = FileOpen(folder + "tong_ket.txt", FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON, 0, CP_UTF8);
   for(int k = 0; k < nl; k++)
     {
      Print("[SmcLab] ", lines[k]);
      if(fh != INVALID_HANDLE)
         FileWriteString(fh, lines[k] + "\r\n");
     }
   if(fh != INVALID_HANDLE)
      FileClose(fh);
   return 0.0;
  }
