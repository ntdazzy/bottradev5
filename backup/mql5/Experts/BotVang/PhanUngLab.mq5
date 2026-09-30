// PhanUngLab: đo vào lệnh khi có phản ứng ở vùng: 5 loại vùng × 4 kiểu phản ứng, so với đối chứng thời điểm ngẫu nhiên
// (RC-T), đảo chiều (RC-D), nhóm X1 (cùng mẫu nến nhưng ngoài vùng) và X2 (chạm vùng là vào). CHỈ ĐỂ ĐO trong Strategy Tester,
// "mọi tick theo tick thật". Khung vào lệnh = khung chạy tester (M1, M5); R4 (CHoCH M1 sau khi chạm vùng M5) chỉ đo khi chạy M5.
// Cách thoát lệnh: mặc định SL đáy/đỉnh lớn, TP = InpTpR × R, 1 lệnh; InpSlMode / InpTp1Price / InpRunnerPrice bật cách
// thoát scalping (SL sau râu, TP1 theo giá hoặc "tùy lực", ăn thêm) cho mọi loại lệnh (thật, RC-T, RC-D, X1, X2).
// InpHtf bật cản khung lớn (HtfZones.mqh): nhóm B (vùng M15/H1/H4/D1, ngày/tuần) có lệnh, RC-T (dãy ngẫu nhiên riêng), RC-D, X2
// riêng; nhóm C / "A không trùng" là nhãn trên lệnh nhóm A. Nhóm A giữ nguyên từng lệnh.
// Không đặt lệnh thật.
#property copyright "BotVang"
#property version   "1.00"
#property description "Đo vào lệnh khi có phản ứng ở vùng FVG / OB / SNR / MSNR / EMA so với đối chứng (SPEC §22). Chỉ để đo."

#include <BotVang/SmcDetect.mqh>
#include <BotVang/SmcZones.mqh>
#include <BotVang/HtfZones.mqh>
#include <BotVang/MarketSim.mqh>
#include <BotVang/MinHeap.mqh>
#include <BotVang/LabStats.mqh>
#include <BotVang/LabRandom.mqh>
#include <BotVang/Stats.mqh>

input string   InpRunName = "pu";             // Tên lần chạy (thư mục kết quả)
input ulong    InpSeed = 1;                   // Hạt giống cho đối chứng ngẫu nhiên
input double   InpSlip = 0.5;                 // Đệm trượt (theo giá) cho mỗi chặng thị trường/lệnh dừng: vàng 0,5; BTC 25; ETH 2,3
input double   InpTpR = 1.0;                  // Chốt lời = số lần R (1; 1,5; 2)
input int      InpSlMode = 0;                 // Dừng lỗ: 0 = đáy/đỉnh lớn 20/20 ngoài mốc; 1 = sau râu nến phản ứng: mốc ∓ 0,1 ATR
input double   InpTp1Price = 0.0;             // Chốt đầu TP1: 0 = theo InpTpR; > 0 = số giá cố định (1, 2, 3, 5); −1 = "tùy lực" theo thân nến phản ứng / ATR
input double   InpRunnerPrice = 0.0;          // Ăn thêm: 0 = không (0,01 lot); > 0 = 0,02 lot, nửa sau dời SL về giá vào khi TP1 khớp, chốt ở giá vào ± số giá này
input int      InpControls = 20;              // Số đối chứng thời điểm ngẫu nhiên cho mỗi lệnh thật
input int      InpWarmBars = 1000;            // Số nến lịch sử nạp trước khi bắt đầu đo
input int      InpMaxHold = 500;              // Giữ lệnh tối đa (nến khung vào lệnh), quá thì đóng theo giá thị trường
input int      InpRctDays = 10;               // Đối chứng thời điểm: cùng giờ, lệch ngẫu nhiên 1..N ngày về sau
input int      InpVnOffset = 7;               // Giờ VN = giờ sàn + số giờ này
input datetime InpCutVn = D'2026.07.06';      // Mốc chia khám phá / kiểm tra (giờ VN)
input bool     InpHtf = false;                // Cản khung lớn M15/H1/H4/D1: thêm nhóm B, C, "A không trùng"; tắt = như cũ

#define R_COUNT    4                        // kiểu phản ứng: ZR_R1, ZR_R2, ZR_R3 (SmcZones.mqh) và R4
#define RI_R4      3
#define CELL_COUNT (ZT_COUNT * R_COUNT)     // ô = loại vùng * R_COUNT + kiểu phản ứng
#define BCELL_COUNT (HZ_COUNT * R_COUNT)    // ô nhóm B; trong lệnh ảo: CELL_COUNT + loại vùng khung lớn * R_COUNT + kiểu phản ứng
#define XG_COUNT   8                        // nhóm X: 0..2 = X1 theo R1, R2, R4; 3..7 = X2 theo loại vùng
#define M1_WIN     15                       // R4: số nến M1 sau nến chạm
#define RCT_SAMPLE 50                       // lenh.csv chỉ ghi đối chứng thời điểm của lệnh thật có mã chia hết cho số này
#define WF_COUNT   ((ZT_COUNT + HZ_COUNT) * 2)   // R4: loại vùng (A: 0..4, B: 5..9) × chiều

string ZoneName[ZT_COUNT] = {"FVG", "OB", "SNR", "MSNR", "EMA"};
string ReactName[R_COUNT] = {"R1 rut rau", "R2 nhan chim", "R3 dong quay ra", "R4 CHoCH M1"};
string XName[XG_COUNT] = {"X1 R1 ngoai vung", "X1 R2 ngoai vung", "X1 R4 ngoai vung", "X2 cham FVG", "X2 cham OB", "X2 cham SNR",
                          "X2 cham MSNR", "X2 cham EMA"};
// X2 nhóm B (trong lệnh ảo: nhóm XG_COUNT + loại vùng khung lớn)
string XNameB[HZ_COUNT] = {"X2 cham HTF FVG", "X2 cham HTF OB", "X2 cham HTF SNR", "X2 cham HTF MSNR", "X2 cham HTF Ngay/Tuan"};

CSmcBars       g_bars;
CSmcStructure  g_st[2];          // 0 nội bộ (5/5), 1 lớp lớn (20/20, dùng cho dừng lỗ)
CSmcFvgs       g_fvg;
CSmcZones      g_zones;
CMarketSim     g_sim;
CRng           g_rng;
bool           g_s24 = false;    // thoát lệnh kiểu scalping (có ít nhất một trong InpSlMode, InpTp1Price, InpRunnerPrice khác mặc định)
bool           g_warm = false;
datetime       g_lastBar = 0;
bool           g_anyPrev = true;  // nến trước có chạm vùng nào không (X1 nhấn chìm)
// R4: nến M1 theo thời gian thực trong lần chạy M5
bool           g_r4 = false;
CSmcBars       g_m1Bars;
CSmcStructure  g_m1St;           // cấu trúc nội bộ M1 (pivot 5/5)
datetime       g_lastM1 = 0;
bool           g_m1Any[M1_WIN + 1];   // nến M1 gần nhất (vòng tròn theo chỉ số) có chạm vùng M5 nào không
SmcZoneHit     g_hits[];
HtfHit         g_bHits[];
// type: loại vùng A (0..4) hoặc ZT_COUNT + loại vùng khung lớn (nhóm B); ref: vùng (ghi lenh_vung.csv, nhãn trùng)
struct R4Watch { int type; int dir; double top; double bottom; int start; double ext; ZoneRef ref; };
R4Watch        g_watch[];
int            g_nWatch = 0;
// lệnh tìm thấy ở nến M1 (R4, X1 R4), vào ở cùng tick sau khi nến M5 (nếu vừa đóng) đã xử lý; tp1 = khoảng TP1 theo giá (Tp1Of)
struct Pending { int kind; int cell; int dir; double base; double tp1; datetime pu; bool htf; ZoneRef ref; };
Pending        g_pend[];
int            g_nPend = 0;
// cản khung lớn
bool           g_htfOn = false;
CHtfZones      g_htf;
CRng           g_rngB;           // RC-T nhóm B: dãy riêng để nhóm A không đổi
CMinHeap       g_rctB, g_rct1B;
int            g_bRctPlaced = 0, g_bRctDrop = 0, g_bRctDropPart = 0, g_bRctSlRedraw = 0;
int            g_bSkipSl = 0, g_bConflict = 0, g_bxSkipSl = 0, g_bxConflict = 0;
// xu hướng khung H1 để lọc chiều mua/bán
#define EMA_N 200
CSmcBars       g_hBars;
CSmcStructure  g_hSt;            // pivot 5/5 trên H1
datetime       g_hLast = 0;      // giờ mở nến H1 đã đóng cuối cùng đã nạp
double         g_ema = 0.0, g_hClose = 0.0;
int            g_emaCnt = 0;
// đối chứng thời điểm ngẫu nhiên: việc chờ (dùng lại chỗ trống) và 2 hàng đợi theo giờ hẹn (giờ mở nến vào lệnh)
#define RCT_ATR_TOL 0.2   // ATR lúc vào đối chứng lệch không quá 20% so với lệnh thật
#define RCT_TRIES   10    // số lần rút ngày tối đa
// risk, tp1: khoảng dừng lỗ và TP1 theo giá của lệnh thật
struct RctJob { datetime due; int dir; double slAtr; double atr; double risk; double tp1; int part; int tries; int arm; };
RctJob         g_job[];
int            g_jobFree[];
CMinHeap       g_rct;            // hẹn theo nến khung vào lệnh (R1–R3)
CMinHeap       g_rct1;           // hẹn theo nến M1 (R4)
int            g_rctPlaced = 0;
int            g_rctDrop = 0;       // hết số lần rút (sàn đóng, biến động khác)
int            g_rctDropPart = 0;   // ngày rút rơi sang phần dữ liệu khác
int            g_rctSlRedraw = 0;   // số lần rút lại vì dừng lỗ chạm ngay tick vào (chênh lệch ≥ khoảng dừng lỗ)
int            g_slAtEntry = 0;     // tự kiểm tra: lệnh ảo bị dừng lỗ ngay ở tick vào (phải bằng 0)
struct RctSample { int order; double atr; };
RctSample      g_rctSample[];
RctSample      g_rctSampleB[];
// mỗi lần vào lệnh thật (g_arms, cell = ô) hoặc lệnh nhóm X (g_xs, cell = nhóm): lúc vào, lúc đóng nến phản ứng, ATR,
// chỉ số lệnh ảo (−1: dừng lỗ đã chạm ngay ở tick vào nên không vào), chiều xu hướng H1 / phía EMA 200 H1 lúc vào (0: chưa biết)
struct ArmInfo { int cell; int dir; datetime t; datetime pu; double atr; int order; int trendDir; int emaDir; };
ArmInfo        g_arms[];
ArmInfo        g_xs[];
// nhóm B: lần vào (g_barms), X2 (g_xsB); vùng của mỗi lần vào (chỉ khi InpHtf): g_aref theo g_arms, g_bref theo g_barms
ArmInfo        g_barms[];
ArmInfo        g_xsB[];
ZoneRef        g_aref[];
ZoneRef        g_bref[];
int            g_just[];         // lệnh thật vừa vào ở tick này (sinh đối chứng đảo chiều)
int            g_nJust = 0;
int            g_skipSl = 0, g_conflict = 0, g_xSkipSl = 0, g_xConflict = 0;
ulong          g_t0 = 0;

int PartOf(datetime server) { return server + InpVnOffset * 3600 < InpCutVn ? 0 : 1; }
int DayOf(datetime server) { return YmdKey(VnDayStart(server, InpVnOffset), InpVnOffset); }
// ô nhóm A (c < CELL_COUNT) hoặc nhóm B (tên bắt đầu "HTF ")
string CellName(int c)
  {
   if(c >= CELL_COUNT)
      return "HTF " + HtfTypeName[(c - CELL_COUNT) / R_COUNT] + " " + ReactName[(c - CELL_COUNT) % R_COUNT];
   return ZoneName[c / R_COUNT] + " " + ReactName[c % R_COUNT];
  }
// Giờ đóng nến khung vào lệnh k (lúc biết của vùng nhóm A xuất hiện ở nến k)
datetime BarClose(int k) { return g_bars.b[k].t + PeriodSeconds(_Period); }
// Vùng nhóm A đã phản ứng kiểu rr (ZR_*) ở nến vừa xét, chiều dir (vùng đại diện của SmcZones, ưu tiên vùng trùng khung lớn)
ZoneRef ARef(int zt, int rr, int dir)
  {
   ZoneRef r;
   ZeroMemory(r);
   r.tf = -1;
   r.type = zt;
   r.id = -1;
   r.tag.ovl = -1;
   r.nearBreak = -1;
   if(!g_htfOn)
      return r;
   SmcZone q = g_zones.rep[(zt * 3 + rr) * 2 + (dir > 0 ? 0 : 1)];
   r.id = q.id;
   r.known = BarClose(q.born);
   r.touch = g_bars.b[q.k0].t;
   r.tag = q.tag;
   r.top = q.top;
   r.bottom = q.bottom;
   return r;
  }
// nhóm X1 ứng với kiểu phản ứng r (R3 không có mẫu ngoài vùng: −1)
int X1Of(int r) { return r == ZR_R1 ? 0 : (r == ZR_R2 ? 1 : (r == RI_R4 ? 2 : -1)); }
// cách chọn mua/bán: 0 mọi tín hiệu; 1 cùng chiều xu hướng H1; 2 cùng phía EMA 200 H1
bool ModeOk(int m, const ArmInfo &a) { return m == 0 || (m == 1 && a.trendDir == a.dir) || (m == 2 && a.emaDir == a.dir); }

int AddInfo(ArmInfo &a[], int cell, int dir, datetime t, datetime pu, double atr)
  {
   int k = ArraySize(a);
   ArrayResize(a, k + 1, 65536);
   a[k].cell = cell;
   a[k].dir = dir;
   a[k].t = t;
   a[k].pu = pu;
   a[k].atr = atr;
   a[k].order = -1;
   a[k].trendDir = g_hSt.trend;
   a[k].emaDir = g_emaCnt < EMA_N ? 0 : (g_hClose > g_ema ? 1 : (g_hClose < g_ema ? -1 : 0));
   return k;
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

// SL: mua = đáy lớn gần nhất có giá ≤ mốc, trừ 0,1 ATR; không có thì mốc − 0,1 ATR. Bán ngược lại.
// InpSlMode = 1: luôn mốc − 0,1 ATR (bán: + 0,1 ATR), không dời ra đáy/đỉnh lớn.
double WideSl(int dir, double base, double atr)
  {
   double p = InpSlMode == 1 ? 0.0 : (dir > 0 ? g_st[1].NearestLow(base) : g_st[1].NearestHigh(base));
   return (p != 0.0 ? p : base) - dir * 0.1 * atr;
  }

// Khoảng TP1 theo giá từ nến phản ứng k (atr = ATR khung của chính nến đó) của lệnh chiều dir: 0 = chốt lời theo InpTpR × R;
// InpTp1Price > 0: cố định; < 0 "tùy lực": thân theo chiều lệnh (mua: đóng − mở; bán: mở − đóng; nến ngược chiều → 1 giá)
// < 0,5 ATR → 1 giá; < 1 ATR → 2; < 1,5 ATR → 3; còn lại → 5
double Tp1Of(int dir, const SmcBar &k)
  {
   if(InpTp1Price >= 0.0)
      return InpTp1Price;
   double f = k.atr > 0.0 ? dir * (k.c - k.o) / k.atr : 0.0;
   return f < 0.5 ? 1.0 : (f < 1.0 ? 2.0 : (f < 1.5 ? 3.0 : 5.0));
  }

// Vào một lần ở tick t: lệnh đơn chốt ở TP1 (tp1 = 0: InpTpR × khoảng dừng lỗ risk), hoặc bản (b)
// (InpRunnerPrice > 0): nửa A chốt ở TP1, nửa B ở giá vào ± InpRunnerPrice, cùng SL. Trả về chỉ số lệnh (nửa A).
int Place(int kind, int cell, int arm, int dir, double sl, double risk, double tp1, const MqlTick &t)
  {
   double entry = dir > 0 ? t.ask : t.bid;
   double tp = tp1 > 0.0 ? entry + dir * tp1 : entry + dir * InpTpR * risk;
   if(InpRunnerPrice <= 0.0)
      return g_sim.Add(kind, cell, arm, dir, sl, tp, t);
   return g_sim.AddPair(kind, cell, arm, dir, sl, tp, entry + dir * InpRunnerPrice, t);
  }

// Kết quả một lần vào ở lệnh k (lệnh đơn hoặc nửa A; nửa B ở k + 1) sau đệm trượt c mỗi chặng, mỗi nửa trả chặng của nó:
// sum = cả lệnh theo giá; px = mỗi 0,01 lot (bản b: tổng 2 nửa / 2); r = px / khoảng dừng lỗ ban đầu. false: có nửa chưa xong khi hết dữ liệu.
bool EntryVal(int k, double c, double &sum, double &px, double &r)
  {
   int nh = g_sim.o[k].half == 1 ? 2 : 1;
   sum = 0.0;
   for(int h = 0; h < nh; h++)
     {
      if(g_sim.o[k + h].reason == MX_END)
         return false;
      sum += CMarketSim::Price(g_sim.o[k + h], c);
     }
   px = sum / nh;
   double risk = MathAbs(g_sim.o[k].fill - g_sim.o[k].sl);
   r = risk > 0.0 ? px / risk : 0.0;
   return true;
  }

// Rút ngày cho đối chứng thời điểm: cùng giờ mở nến, 1..InpRctDays ngày sau lần hẹn trước, sau nến barOpen.
// Trả về false (bỏ) khi hết số lần rút hoặc ngày rút rơi sang phần dữ liệu khác. htf: nhóm B (dãy ngẫu nhiên và bộ đếm riêng).
bool RctDraw(RctJob &j, datetime barOpen, bool htf)
  {
   do
     {
      if(j.tries >= RCT_TRIES)
        {
         if(htf)
            g_bRctDrop++;
         else
            g_rctDrop++;
         return false;
        }
      j.tries++;
      j.due += (1 + (htf ? g_rngB.Below(InpRctDays) : g_rng.Below(InpRctDays))) * 86400;
     }
   while(j.due <= barOpen);
   if(PartOf(j.due) != j.part)
     {
      if(htf)
         g_bRctDropPart++;
      else
         g_rctDropPart++;
      return false;
     }
   return true;
  }

int NewJob(const RctJob &j)
  {
   int s;
   int f = ArraySize(g_jobFree);
   if(f > 0)
     {
      s = g_jobFree[f - 1];
      ArrayResize(g_jobFree, f - 1, 65536);
     }
   else
     {
      s = ArraySize(g_job);
      ArrayResize(g_job, s + 1, 65536);
     }
   g_job[s] = j;
   return s;
  }

void FreeJob(int s)
  {
   int f = ArraySize(g_jobFree);
   ArrayResize(g_jobFree, f + 1, 65536);
   g_jobFree[f] = s;
  }

// Dừng lỗ đã chạm ở tick t theo đúng phía
bool StopHit(int dir, double sl, const MqlTick &t) { return dir > 0 ? t.bid <= sl : t.ask >= sl; }

// Lệnh thật vào ngay ở tick t (mua giá Ask, bán giá Bid) và lịch đối chứng thời điểm ngẫu nhiên hẹn theo giờ mở nến vào lệnh due
// (m1 = true: nến M1, cho R4); tp1 = khoảng TP1 theo giá (Tp1Of của nến phản ứng). htf: nhóm B (sổ, hàng đợi RC-T, dãy ngẫu nhiên riêng);
// ref: vùng đã sinh lệnh (ghi khi InpHtf)
void ArmReal(bool htf, int cell, int dir, double base, double atr, double tp1, datetime pu, datetime due, bool m1, const MqlTick &t,
             const ZoneRef &ref)
  {
   int a = htf ? AddInfo(g_barms, cell, dir, t.time, pu, atr) : AddInfo(g_arms, cell, dir, t.time, pu, atr);
   if(g_htfOn)
     {
      if(htf)
        {
         ArrayResize(g_bref, a + 1, 65536);
         g_bref[a] = ref;
        }
      else
        {
         ArrayResize(g_aref, a + 1, 65536);
         g_aref[a] = ref;
        }
     }
   double entry = dir > 0 ? t.ask : t.bid;
   double sl = WideSl(dir, base, atr);
   double risk = (entry - sl) * dir;
   if(StopHit(dir, sl, t) || atr <= 0.0)
     {
      if(htf)
         g_bSkipSl++;
      else
         g_skipSl++;   // dừng lỗ đã chạm ngay ở tick vào (giá nhảy qua mốc, hoặc chênh lệch ≥ khoảng dừng lỗ): không vào
      return;
     }
   int k = Place(MK_REAL, cell, a, dir, sl, risk, tp1, t);
   if(htf)
      g_barms[a].order = k;
   else
      g_arms[a].order = k;
   ArrayResize(g_just, g_nJust + 1, 64);
   g_just[g_nJust++] = k;
   for(int c = 0; c < InpControls; c++)
     {
      RctJob j;
      j.due = due;
      j.dir = dir;
      j.slAtr = risk / atr;
      j.atr = atr;
      j.risk = risk;
      j.tp1 = tp1;
      j.part = PartOf(t.time);
      j.tries = 0;
      j.arm = a;
      if(!RctDraw(j, due, htf))
         continue;
      int s = NewJob(j);
      if(htf)
        {
         if(m1)
            g_rct1B.Push((double)j.due, s);
         else
            g_rctB.Push((double)j.due, s);
        }
      else
         if(m1)
            g_rct1.Push((double)j.due, s);
         else
            g_rct.Push((double)j.due, s);
     }
  }

// Lệnh nhóm X1/X2 (không có đối chứng): vào ngay ở tick t, dừng lỗ/chốt lời như lệnh thật; htf: X2 nhóm B (sổ riêng)
void ArmX(int kind, int group, int dir, double base, double atr, double tp1, datetime pu, const MqlTick &t, bool htf = false)
  {
   double entry = dir > 0 ? t.ask : t.bid;
   double sl = WideSl(dir, base, atr);
   double risk = (entry - sl) * dir;
   if(StopHit(dir, sl, t) || atr <= 0.0)
     {
      if(htf)
         g_bxSkipSl++;
      else
         g_xSkipSl++;
      return;
     }
   if(htf)
     {
      int x = AddInfo(g_xsB, group, dir, t.time, pu, atr);
      g_xsB[x].order = Place(kind, group, x, dir, sl, risk, tp1, t);
      return;
     }
   int x = AddInfo(g_xs, group, dir, t.time, pu, atr);
   g_xs[x].order = Place(kind, group, x, dir, sl, risk, tp1, t);
  }

// Đối chứng thời điểm tới hạn ở nến mới mở lúc barOpen (atr = ATR nến khung vào lệnh đã đóng cuối); htf: hàng đợi của nhóm B
void RunRct(CMinHeap &q, datetime barOpen, double atr, const MqlTick &t, bool htf = false)
  {
   while(q.n > 0 && q.TopKey() <= (double)barOpen)
     {
      int s = q.TopId();
      q.Pop();
      RctJob j = g_job[s];
      double entry = j.dir > 0 ? t.ask : t.bid;
      double risk = g_s24 ? j.risk : j.slAtr * atr;   // cùng khoảng dừng lỗ theo giá như lệnh thật (vẫn ghép giờ và ATR)
      double sl = entry - j.dir * risk;
      // không có nến đúng giờ hẹn (sàn đóng), biến động khác lệnh thật, hoặc dừng lỗ chạm ngay tick vào (như lệnh thật): rút ngày khác
      bool miss = j.due < barOpen || MathAbs(atr / j.atr - 1.0) > RCT_ATR_TOL;
      if(!miss && StopHit(j.dir, sl, t))
        {
         if(htf)
            g_bRctSlRedraw++;
         else
            g_rctSlRedraw++;
         miss = true;
        }
      if(miss)
        {
         if(RctDraw(j, barOpen, htf))
           {
            g_job[s] = j;
            q.Push((double)j.due, s);
           }
         else
            FreeJob(s);
         continue;
        }
      FreeJob(s);
      if(htf)
        {
         int k = Place(MK_RCT, g_barms[j.arm].cell, j.arm, j.dir, sl, risk, j.tp1, t);
         g_bRctPlaced++;
         if(j.arm % RCT_SAMPLE == 0)
           {
            int m = ArraySize(g_rctSampleB);
            ArrayResize(g_rctSampleB, m + 1, 4096);
            g_rctSampleB[m].order = k;
            g_rctSampleB[m].atr = atr;
           }
         continue;
        }
      int k = Place(MK_RCT, g_arms[j.arm].cell, j.arm, j.dir, sl, risk, j.tp1, t);
      g_rctPlaced++;
      if(j.arm % RCT_SAMPLE == 0)
        {
         int m = ArraySize(g_rctSample);
         ArrayResize(g_rctSample, m + 1, 4096);
         g_rctSample[m].order = k;
         g_rctSample[m].atr = atr;
        }
     }
  }

// Lệnh thật vừa vào: sinh đối chứng đảo chiều (vào ngay, ngược chiều, cùng khoảng dừng lỗ và cùng bội số chốt lời). Lệnh thật là
// lệnh thị trường nên lệnh đảo chiều cũng trả đệm trượt lúc vào (cùng phí). Cùng khoảng dừng lỗ và TP1 theo giá, cùng phần ăn thêm.
void SpawnFlips(const MqlTick &t)
  {
   for(int q = 0; q < g_nJust; q++)
     {
      MOrder v = g_sim.o[g_just[q]];
      double risk = MathAbs(v.fill - v.sl);
      double tpR = MathAbs(v.tp - v.fill) / risk;
      int dir = -v.dir;
      double entry = dir > 0 ? t.ask : t.bid;
      if(g_s24)
         Place(MK_RCD, v.cell, v.arm, dir, entry - dir * risk, risk, MathAbs(v.tp - v.fill), t);
      else
         g_sim.Add(MK_RCD, v.cell, v.arm, dir, entry - dir * risk, entry + dir * tpR * risk, t);
     }
   g_nJust = 0;
  }

// Mặt nạ chiều ZS_* của một ô ở một nến → chiều lệnh (0: không có). Có cả mua lẫn bán cùng nến thì bỏ (đếm vào conflict),
// vì mỗi ô chỉ vào tối đa 1 lệnh mỗi nến.
int DirOf(int mask, int &conflict)
  {
   if(mask == (ZS_BUY | ZS_SELL))
     {
      conflict++;
      return 0;
     }
   return mask == ZS_BUY ? 1 : (mask == ZS_SELL ? -1 : 0);
  }

// Xử lý một nến khung vào lệnh đã đóng; trade = false khi đang nạp lịch sử
void ProcessBar(const MqlRates &r, bool trade, const MqlTick &t)
  {
   int i = g_bars.Add(r);
   g_sim.curBar = i;
   g_fvg.OnBar(g_bars, i);
   SmcBreak ev[2];
   for(int L = 0; L < 2; L++)
      g_st[L].OnBar(g_bars, i, ev[L]);
   g_zones.OnBar(g_bars, i, ev[0], ev[1], g_fvg);   // nhãn trùng (InpHtf) theo vùng khung lớn lúc mở nến này (chưa nạp nến khung lớn đóng lúc nến này đóng)
   if(g_htfOn)
      g_htf.OnBar(g_bars, i);
   bool anyPrev = g_anyPrev;
   g_anyPrev = g_zones.anyTouch;
   if(!trade || !g_bars.Ready() || i < 1)
      return;
   double atr = g_bars.b[i].atr;
   SmcBar b = g_bars.b[i], a = g_bars.b[i - 1];
   datetime pu = r.time + PeriodSeconds(_Period);   // lúc đóng nến phản ứng
   // đóng lệnh giữ quá lâu theo nến vừa đóng, đối chứng thời điểm tới hạn, rồi mới vào lệnh mới
   g_sim.OnBar(i, InpMaxHold, t);
   RunRct(g_rct, g_lastBar, atr, t);
   if(g_htfOn)
      RunRct(g_rctB, g_lastBar, atr, t, true);
   // R1–R3: mỗi ô tối đa 1 lệnh mỗi nến dù nhiều vùng cùng phản ứng; mốc dừng lỗ = đáy nến phản ứng (R2: của 2 nến)
   for(int zt = 0; zt < ZT_COUNT; zt++)
      for(int rr = ZR_R1; rr <= ZR_R3; rr++)
        {
         int dir = DirOf(g_zones.react[zt * 3 + rr], g_conflict);
         if(dir == 0)
            continue;
         double base = dir > 0 ? b.l : b.h;
         if(rr == ZR_R2)
            base = dir > 0 ? MathMin(base, a.l) : MathMax(base, a.h);
         ArmReal(false, zt * R_COUNT + rr, dir, base, atr, Tp1Of(dir, b), pu, g_lastBar, false, t, ARef(zt, rr, dir));   // nến phản ứng (R2: nến nhấn chìm) = b
        }
   // X2: mọi lần chạm đầu của vùng → vào ngay, mốc = đáy nến chạm (mỗi loại vùng tối đa 1 lệnh mỗi nến); "tùy lực" theo nến chạm
   for(int zt = 0; zt < ZT_COUNT; zt++)
     {
      int dir = DirOf(g_zones.touched[zt], g_xConflict);
      if(dir != 0)
         ArmX(MK_X2, 3 + zt, dir, dir > 0 ? b.l : b.h, atr, Tp1Of(dir, b), pu, t);
     }
   // X1: mẫu rút râu / nhấn chìm không chạm vùng nào trong 5 loại (nhấn chìm: cả 2 nến không chạm)
   if(!g_zones.anyTouch)
     {
      int dir = DirOf((PinShape(1, b) ? ZS_BUY : 0) | (PinShape(-1, b) ? ZS_SELL : 0), g_xConflict);
      if(dir != 0)
         ArmX(MK_X1, 0, dir, dir > 0 ? b.l : b.h, atr, Tp1Of(dir, b), pu, t);
      if(!anyPrev)
        {
         dir = DirOf((EngulfShape(1, a, b) ? ZS_BUY : 0) | (EngulfShape(-1, a, b) ? ZS_SELL : 0), g_xConflict);
         if(dir != 0)
            ArmX(MK_X1, 1, dir, dir > 0 ? MathMin(a.l, b.l) : MathMax(a.h, b.h), atr, Tp1Of(dir, b), pu, t);
        }
     }
   if(!g_htfOn)
      return;
   // nhóm B: như R1–R3 và X2 ở trên, trên vùng khung lớn; X1 dùng chung của nhóm A
   for(int bt = 0; bt < HZ_COUNT; bt++)
      for(int rr = ZR_R1; rr <= ZR_R3; rr++)
        {
         int dir = DirOf(g_htf.react[bt * 3 + rr], g_bConflict);
         if(dir == 0)
            continue;
         double base = dir > 0 ? b.l : b.h;
         if(rr == ZR_R2)
            base = dir > 0 ? MathMin(base, a.l) : MathMax(base, a.h);
         ArmReal(true, CELL_COUNT + bt * R_COUNT + rr, dir, base, atr, Tp1Of(dir, b), pu, g_lastBar, false, t,
                 g_htf.rep[(bt * 3 + rr) * 2 + (dir > 0 ? 0 : 1)]);
        }
   for(int bt = 0; bt < HZ_COUNT; bt++)
     {
      int dir = DirOf(g_htf.touched[bt], g_bxConflict);
      if(dir != 0)
         ArmX(MK_X2, XG_COUNT + bt, dir, dir > 0 ? b.l : b.h, atr, Tp1Of(dir, b), pu, t, true);
     }
  }

void AddPending(int kind, int cell, int dir, double base, double tp1, datetime pu, bool htf, const ZoneRef &ref)
  {
   ArrayResize(g_pend, g_nPend + 1, 64);
   g_pend[g_nPend].kind = kind;
   g_pend[g_nPend].cell = cell;
   g_pend[g_nPend].dir = dir;
   g_pend[g_nPend].base = base;
   g_pend[g_nPend].tp1 = tp1;
   g_pend[g_nPend].pu = pu;
   g_pend[g_nPend].htf = htf;
   g_pend[g_nPend].ref = ref;
   g_nPend++;
  }

void AddWatch(int type, int dir, double top, double bottom, int start, double ext, const ZoneRef &ref)
  {
   if(g_nWatch >= ArraySize(g_watch))
      ArrayResize(g_watch, 2 * g_nWatch + 64);
   g_watch[g_nWatch].type = type;
   g_watch[g_nWatch].dir = dir;
   g_watch[g_nWatch].top = top;
   g_watch[g_nWatch].bottom = bottom;
   g_watch[g_nWatch].start = start;
   g_watch[g_nWatch].ext = ext;
   g_watch[g_nWatch].ref = ref;
   g_nWatch++;
  }

// Một nến M1 vừa đóng (chỉ khi chạy M5): cấu trúc nội bộ M1, lần chạm M1 đầu của vùng M5, theo dõi R4 và mẫu X1 R4.
// R4: CHoCH ở 1 trong 15 nến M1 sau nến chạm (không tính chính nến chạm); hủy khi một nến M1 (kể cả nến chạm) đóng qua mép xa.
void ProcessM1(const MqlRates &r, bool live)
  {
   int mi = g_m1Bars.Add(r);
   SmcBreak ev;
   g_m1St.OnBar(g_m1Bars, mi, ev);
   if(!live)
      return;
   SmcBar m = g_m1Bars.b[mi];
   int nh = 0;
   g_m1Any[mi % (M1_WIN + 1)] = g_zones.OnM1Bar(m, g_bars.n, g_hits, nh);   // g_bars.n = nến M5 đang chạy chứa nến M1 này
   ZoneRef ref;
   ZeroMemory(ref);
   ref.tf = -1;
   ref.nearBreak = -1;
   for(int h = 0; h < nh; h++)
     {
      ref.type = g_hits[h].type;
      ref.id = g_hits[h].id;
      ref.known = BarClose(g_hits[h].born);
      ref.touch = m.t;
      ref.tag = g_hits[h].tag;
      ref.top = g_hits[h].top;
      ref.bottom = g_hits[h].bottom;
      AddWatch(g_hits[h].type, g_hits[h].dir, g_hits[h].top, g_hits[h].bottom, mi, g_hits[h].dir > 0 ? m.l : m.h, ref);
     }
   if(g_htfOn)
     {
      g_htf.OnM1Bar(m, g_bHits, nh);   // nhóm B: loại vùng ghi thành ZT_COUNT + loại
      for(int h = 0; h < nh; h++)
         AddWatch(ZT_COUNT + g_bHits[h].type, g_bHits[h].dir, g_bHits[h].top, g_bHits[h].bottom, mi, g_bHits[h].dir > 0 ? m.l : m.h,
                  g_bHits[h].ref);
     }
   bool choch = ev.valid && !ev.initial && ev.choch;
   // nhiều vùng cùng loại cùng có CHoCH ở nến này: 1 lệnh, mốc dừng lỗ xa nhất (từ lần chạm sớm nhất); vùng đại diện: nhóm A ưu tiên
   // vùng trùng khung lớn, nhóm B vùng khung lớn nhất
   double base[WF_COUNT];
   bool has[WF_COUNT];
   ZoneRef fref[WF_COUNT];
   ArrayInitialize(has, false);
   ArrayInitialize(base, 0.0);
   int keep = 0;
   for(int k = 0; k < g_nWatch; k++)
     {
      R4Watch w = g_watch[k];
      if(mi - w.start > M1_WIN)
         continue;   // hết cửa sổ
      w.ext = w.dir > 0 ? MathMin(w.ext, m.l) : MathMax(w.ext, m.h);
      if(w.dir > 0 ? m.c < w.bottom : m.c > w.top)
         continue;   // nến M1 đóng qua mép xa của vùng (kể cả nến chạm): hủy
      if(choch && ev.dir == w.dir && mi > w.start)   // CHoCH phải ở 1 trong 15 nến M1 SAU nến chạm
        {
         int f = w.type * 2 + (w.dir > 0 ? 0 : 1);
         if(!has[f] || (w.dir > 0 ? w.ext < base[f] : w.ext > base[f]))
            base[f] = w.ext;
         if(!has[f] || (w.type >= ZT_COUNT ? w.ref.tf > fref[f].tf : (w.ref.tag.ovl == 1 && fref[f].tag.ovl != 1)))
            fref[f] = w.ref;
         has[f] = true;
         continue;   // đã phản ứng: bỏ theo dõi
        }
      g_watch[keep++] = w;
     }
   g_nWatch = keep;
   datetime pu = r.time + 60;   // lúc đóng nến M1 có CHoCH
   for(int f = 0; f < ZT_COUNT * 2; f++)
      if(has[f])
        {
         int dir = f % 2 == 0 ? 1 : -1;
         AddPending(MK_REAL, (f / 2) * R_COUNT + RI_R4, dir, base[f], Tp1Of(dir, m), pu, false, fref[f]);   // "tùy lực": nến M1 có CHoCH, ATR M1
        }
   // X1 R4: CHoCH M1 mà nến CHoCH và 15 nến M1 trước nó (mọi nến có thể là nến chạm của R4) không chạm vùng M5 nào;
   // mốc = đáy thấp nhất (đỉnh cao nhất) 16 nến đó
   if(choch && mi >= M1_WIN)
     {
      bool noZone = true;
      for(int k = 0; k <= M1_WIN; k++)
         if(g_m1Any[k])
            noZone = false;
      if(noZone)
        {
         double ext = ev.dir > 0 ? m.l : m.h;
         for(int k = mi - M1_WIN; k < mi; k++)
            ext = ev.dir > 0 ? MathMin(ext, g_m1Bars.b[k].l) : MathMax(ext, g_m1Bars.b[k].h);
         AddPending(MK_X1, 2, ev.dir, ext, Tp1Of(ev.dir, m), pu, false, ref);
        }
     }
   // R4 nhóm B
   for(int f = ZT_COUNT * 2; f < WF_COUNT; f++)
      if(has[f])
        {
         int dir = f % 2 == 0 ? 1 : -1;
         AddPending(MK_REAL, CELL_COUNT + (f / 2 - ZT_COUNT) * R_COUNT + RI_R4, dir, base[f], Tp1Of(dir, m), pu, true, fref[f]);
        }
  }

// Vào các lệnh tìm thấy ở nến M1 (sau khi nến M5 vừa đóng, nếu có, đã xử lý) rồi chạy đối chứng thời điểm hẹn theo nến M1
void PlacePending(const MqlTick &t)
  {
   double atr = g_bars.b[g_bars.n - 1].atr;
   for(int k = 0; k < g_nPend; k++)
      if(g_pend[k].kind == MK_REAL)
         ArmReal(g_pend[k].htf, g_pend[k].cell, g_pend[k].dir, g_pend[k].base, atr, g_pend[k].tp1, g_pend[k].pu, g_lastM1, true, t,
                 g_pend[k].ref);
      else
         ArmX(MK_X1, g_pend[k].cell, g_pend[k].dir, g_pend[k].base, atr, g_pend[k].tp1, g_pend[k].pu, t);
   g_nPend = 0;
   RunRct(g_rct1, g_lastM1, atr, t);
   if(g_htfOn)
      RunRct(g_rct1B, g_lastM1, atr, t, true);
  }

int OnInit()
  {
   g_bars.Init();
   g_st[0].Init(5);
   g_st[1].Init(20);
   g_fvg.Init();
   g_zones.Init();
   g_sim.Init();
   g_rng.Seed(RngMix(InpSeed, 0x9A7E));
   g_s24 = InpSlMode != 0 || InpTp1Price != 0.0 || InpRunnerPrice > 0.0;
   g_r4 = _Period == PERIOD_M5;
   g_m1Bars.Init();
   g_m1St.Init(5);
   ArrayInitialize(g_m1Any, true);   // chưa đủ 16 nến M1 đã xét thì chưa có X1 R4
   g_rct.Init();
   g_rct1.Init();
   g_hBars.Init();
   g_hSt.Init(5);
   g_htfOn = InpHtf;
   if(g_htfOn)
     {
      g_htf.Init();
      g_zones.tagger = GetPointer(g_htf);
      g_rngB.Seed(RngMix(InpSeed, 0xB7F2));
      g_rctB.Init();
      g_rct1B.Init();
     }
   g_t0 = GetTickCount64();
   return INIT_SUCCEEDED;
  }

void OnTick()
  {
   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t))
      return;
   if(!g_warm)
     {
      // nạp lịch sử: các nến đã đóng trước nến hiện tại, không vào lệnh
      MqlRates h[];
      ArraySetAsSeries(h, false);
      int got = CopyRates(_Symbol, _Period, 1, InpWarmBars, h);
      if(g_htfOn && got > 0)
         g_htf.Warm(h[0].time, h[0].open);   // khung lớn tới nến nạp lịch sử đầu tiên (kể cả xét đúng phía bằng giá mở nến này)
      for(int k = 0; k < got; k++)
        {
         ProcessBar(h[k], false, t);
         if(g_htfOn)
           {
            // như lúc chạy: sau nến vừa đóng, nạp nến khung lớn đóng tới giờ mở nến sau, rồi xét đúng phía bằng giá mở nến sau
            datetime te = k + 1 < got ? h[k + 1].time : iTime(_Symbol, _Period, 0);
            g_htf.Sync(te, g_bars, false);
            g_htf.ArmCheck(k + 1 < got ? h[k + 1].open : iOpen(_Symbol, _Period, 0), te);
           }
        }
      SyncH1();
      g_lastBar = iTime(_Symbol, _Period, 0);
      int got1 = 0;
      if(g_r4)
        {
         got1 = CopyRates(_Symbol, PERIOD_M1, 1, InpWarmBars, h);
         for(int k = 0; k < got1; k++)
            ProcessM1(h[k], false);
         g_lastM1 = iTime(_Symbol, PERIOD_M1, 0);
        }
      g_warm = true;
      PrintFormat("[PhanUngLab] nạp %d nến lịch sử (%d nến M1), bắt đầu đo từ %s", got, got1, TimeToString(g_lastBar));
     }
   int n0 = g_sim.n;   // lệnh ảo vào ở tick này bắt đầu từ chỉ số n0 (tự kiểm tra dừng lỗ ngay tick vào)
   // nến M1 vừa đóng được xét trước nến khung vào lệnh: vùng xuất hiện lúc đóng nến M5 này chưa dùng được cho nó
   bool newM1 = false;
   if(g_r4)
     {
      datetime m1 = iTime(_Symbol, PERIOD_M1, 0);
      if(m1 != g_lastM1 && m1 != 0)
        {
         g_lastM1 = m1;
         newM1 = true;
         MqlRates r[];
         if(CopyRates(_Symbol, PERIOD_M1, 1, 1, r) == 1)
            ProcessM1(r[0], true);
        }
     }
   datetime bar = iTime(_Symbol, _Period, 0);
   if(bar != g_lastBar && bar != 0)
     {
      g_lastBar = bar;
      SyncH1();   // nến H1 vừa đóng (nếu có) được nạp trước khi vào lệnh ở nến này
      MqlRates r[];
      if(CopyRates(_Symbol, _Period, 1, 1, r) == 1)
         ProcessBar(r[0], true, t);
      if(g_htfOn)
        {
         // vùng khung lớn biết lúc bar (và hỏng/lật lúc đó) chỉ áp dụng từ nến này; nến mở đúng phía thì vùng nhận chạm từ nến này
         g_htf.Sync(bar, g_bars, true);
         g_htf.ArmCheck(iOpen(_Symbol, _Period, 0), bar);
        }
     }
   if(newM1)
      PlacePending(t);
   g_sim.OnTick(t);
   for(int k = n0; k < g_sim.n; k++)
      if(g_sim.o[k].reason == MX_SL)
         g_slAtEntry++;
   SpawnFlips(t);
  }

string Num(double v, int d = 3) { return (v >= 0 ? "+" : "") + DoubleToString(v, d); }

// Cách thoát lệnh ghi ở dòng đầu tong_ket.txt
string ExitText(void)
  {
   if(!g_s24)
      return "chốt lời " + DoubleToString(InpTpR, 1) + "R";
   string sl = InpSlMode == 1 ? "sau râu nến phản ứng (mốc ∓ 0,1 ATR khung vào lệnh)" : "đáy/đỉnh lớn 20/20 ngoài mốc (§22.3)";
   string tp = InpTp1Price > 0.0 ? "= giá vào (mua: Ask, bán: Bid) ± " + DoubleToString(InpTp1Price, 2) + " giá" :
               (InpTp1Price < 0.0 ? "= giá vào (mua: Ask, bán: Bid) ± tùy lực (thân nến theo chiều lệnh / ATR khung của nến đó: < 0,5 → 1 giá, < 1 → 2, < 1,5 → 3, còn lại 5; nến ngược chiều → 1 giá; X1: nến mẫu; X2: nến chạm)" :
                DoubleToString(InpTpR, 1) + "R");
   string run = InpRunnerPrice > 0.0 ? "có: 0,02 lot, 0,01 chốt ở TP1, 0,01 còn lại dời SL về giá vào ngay khi TP1 khớp và chốt ở giá vào ± " +
                DoubleToString(InpRunnerPrice, 2) + " giá" : "không (0,01 lot, đóng hết ở TP1)";
   return "thoát lệnh §24: dừng lỗ " + sl + "; TP1 " + tp + "; ăn thêm " + run +
          "; RC-T, RC-D cùng khoảng dừng lỗ và TP theo giá như lệnh thật; kết quả mỗi lần vào = tổng các nửa sau phí quy về mỗi 0,01 lot" +
          " (có ăn thêm: chia 2), R = giá mỗi 0,01 lot / khoảng dừng lỗ; tổng lệnh ảo đếm từng nửa";
  }

bool EnoughData(CSamples &s) { return s.Days() >= 20 && s.Count() >= 30; }

string CiText(CSamples &s, ulong seed)
  {
   double lo, hi;
   if(!EnoughData(s) || !s.CI(2000, seed, BootRank(2000, 0.05), lo, hi))
      return "[ít dữ liệu]";
   return "[" + Num(lo) + "; " + Num(hi) + "]";
  }

// Hiệu trung bình hai nhóm độc lập (a − b) và KTC 95% (lấy mẫu lại theo ngày, mỗi nhóm riêng, 2000 lần)
string DiffText(CSamples &a, CSamples &b, ulong seed)
  {
   if(a.Count() == 0 || b.Count() == 0)
      return "không có";
   double lo, hi;
   string mean = Num(a.Mean() - b.Mean());
   if(!EnoughData(a) || !EnoughData(b) || !a.DiffCI(b, 2000, seed, BootRank(2000, 0.05), lo, hi))
      return mean + " [ít dữ liệu]";
   return mean + " [" + Num(lo) + "; " + Num(hi) + "]";
  }

// ex: cột thêm khi thoát kiểu scalping (OrderExtra), rỗng ở cách thoát mặc định
string OrderLine(const MOrder &v, string name, string pu, double atr, string trend, string ema, string ex)
  {
   bool done = v.reason != MX_END;
   return StringFormat("%d;%s;%d;%d;%s;%s;%s;%s;%s;%s;%d;%s;%s;%s;%s;%s%s\r\n", v.arm, name, (int)v.kind, (int)v.dir, pu,
                       TimeToString(v.fillTime, TIME_DATE | TIME_SECONDS), TimeToString(v.exitTime, TIME_DATE | TIME_SECONDS),
                       DoubleToString(v.fill, _Digits), DoubleToString(v.sl, _Digits), DoubleToString(v.tp, _Digits), (int)v.reason,
                       done ? DoubleToString(CMarketSim::R(v, 0.0), 3) : "", done ? DoubleToString(CMarketSim::R(v, InpSlip), 3) : "",
                       DoubleToString(atr, _Digits), trend, ema, ex);
  }

// Cột thêm của lenh.csv khi thoát kiểu scalping: nửa (0 lệnh đơn, 1 nửa A, 2 nửa B); hòa vốn (1: nửa B đã dời SL về giá vào); kết quả
// nửa này theo giá sau phí; ở dòng lệnh đơn / nửa A: kết quả cả lần vào theo giá (tổng các nửa), mỗi 0,01 lot, R của lần vào
string OrderExtra(int k)
  {
   MOrder v = g_sim.o[k];
   string s = StringFormat(";%d;%d;%s", (int)v.half, (int)v.be, v.reason != MX_END ? DoubleToString(CMarketSim::Price(v, InpSlip), 3) : "");
   double sum, px, r;
   if(v.half != 2 && EntryVal(k, InpSlip, sum, px, r))
      return s + ";" + DoubleToString(sum, 3) + ";" + DoubleToString(px, 3) + ";" + DoubleToString(r, 3);
   return s + ";;;";
  }

// Mẫu đối chứng thời điểm (cả 2 nửa nếu có ăn thêm)
void WriteRctSample(int h, const RctSample &smp[])
  {
   for(int s = 0; s < ArraySize(smp); s++)
     {
      int k0 = smp[s].order;
      for(int k = k0; k <= (g_sim.o[k0].half == 1 ? k0 + 1 : k0); k++)
        {
         MOrder v = g_sim.o[k];
         FileWriteString(h, OrderLine(v, CellName(v.cell), "", smp[s].atr, "", "", g_s24 ? OrderExtra(k) : ""));
        }
     }
  }

// File từng lệnh: lệnh thật, đảo chiều, X1, X2; đối chứng thời điểm chỉ ghi mẫu (lệnh thật có mã chia hết cho RCT_SAMPLE).
// InpHtf: các dòng nhóm B (ô "HTF ...", "X2 cham HTF ...", arm = mã trong sổ nhóm B) xen giữa theo thứ tự lệnh ảo, mẫu RC-T nhóm B sau
// mẫu nhóm A, một dòng chú thích cuối file; bỏ các dòng có chữ HTF thì còn đúng file của nhóm A.
void WriteOrders(string folder)
  {
   int h = FileOpen(folder + "lenh.csv", FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON, 0, CP_UTF8);
   if(h == INVALID_HANDLE)
      return;
   string head = StringFormat("# kieu: 0 lenh that, 3 dao chieu (RC-D), 4 nhom X1, 5 nhom X2 (arm = ma trong nhom X); 2 doi chung thoi diem (RC-T) chi ghi cua lenh that co arm chia het cho %d cho file nho; pu_dong = luc dong nen phan ung", RCT_SAMPLE);
   string cols = "arm;o;kieu;chieu;pu_dong;khop_luc;dong_luc;vao;sl;tp;ly_do;R0;Rc;atr;xu_huong_H1;ema_H1";
   if(g_s24)
     {
      head += "; thoat lenh SPEC 24: moi nua mot dong (nua 0 lenh don, 1 nua A chot o TP1, 2 nua B an them, ngay sau nua A); sl = SL ban dau; hoa_von 1 = nua B da doi SL ve gia vao khi nua A chot loi; gia_c = ket qua nua nay theo gia sau phi; gia_lan_vao = tong cac nua, gia_001 = moi 0,01 lot, R_lan_vao = gia_001 / |vao - sl| (chi o dong nua 0/1)";
      cols += ";nua;hoa_von;gia_c;gia_lan_vao;gia_001;R_lan_vao";
     }
   FileWriteString(h, head + "\r\n");
   FileWriteString(h, cols + "\r\n");
   for(int k = 0; k < g_sim.n; k++)
     {
      MOrder v = g_sim.o[k];
      if(v.kind == MK_RCT)
         continue;
      ArmInfo a;
      string name;
      if(v.kind == MK_X1 || v.kind == MK_X2)
        {
         if(v.cell >= XG_COUNT)
           {
            a = g_xsB[v.arm];
            name = XNameB[v.cell - XG_COUNT];
           }
         else
           {
            a = g_xs[v.arm];
            name = XName[v.cell];
           }
        }
      else
        {
         if(v.cell >= CELL_COUNT)
            a = g_barms[v.arm];
         else
            a = g_arms[v.arm];
         name = CellName(v.cell);
        }
      FileWriteString(h, OrderLine(v, name, TimeToString(a.pu, TIME_DATE | TIME_SECONDS), a.atr, IntegerToString(a.trendDir),
                                   IntegerToString(a.emaDir), g_s24 ? OrderExtra(k) : ""));
     }
   WriteRctSample(h, g_rctSample);
   if(g_htfOn)
     {
      WriteRctSample(h, g_rctSampleB);
      FileWriteString(h, "# HTF (SPEC 25): dong co o 'HTF ...' la nhom B (vung khung lon), 'X2 cham HTF ...' la X2 cua nhom B; arm cua nhom B la ma trong so nhom B; vung cua tung lan vao (ca nhom A: nhan trung C) o lenh_vung.csv\r\n");
     }
   FileClose(h);
  }

// Một dòng lenh_vung.csv: lần vào a của nhóm grp và vùng đã sinh ra nó
string RefLine(string grp, int a, const ArmInfo &x, const ZoneRef &r)
  {
   bool entryTf = r.tf < 0;
   string s = StringFormat("%s;%d;%s;%d;%s;%s;%s;%s;%d;%s;%s;%s;%s;%s", grp, a, CellName(x.cell), x.dir, TimeToString(x.pu, TIME_DATE | TIME_SECONDS),
                           x.order >= 0 ? TimeToString(g_sim.o[x.order].fillTime, TIME_DATE | TIME_SECONDS) : "",
                           entryTf ? StringSubstr(EnumToString(_Period), 7) : HtfTfName[r.tf], entryTf ? ZoneName[r.type] : HtfTypeName[r.type],
                           r.id, DoubleToString(r.bottom, 6), DoubleToString(r.top, 6), TimeToString(r.known), r.armed > 0 ? TimeToString(r.armed) : "", TimeToString(r.touch));
   if(entryTf && r.tag.ovl >= 0)
     {
      bool o = r.tag.ovl == 1;
      s += StringFormat(";%d;%s;%s;%s;%s;%s;%s;%d", r.tag.ovl, o ? IntegerToString(r.tag.hId) : "", o ? HtfTfName[r.tag.hTf] : "",
                        o ? HtfTypeName[r.tag.hType] : "", o ? DoubleToString(r.tag.hBottom, _Digits) : "",
                        o ? DoubleToString(r.tag.hTop, _Digits) : "", DoubleToString(r.tag.d, 6), (int)r.tag.msnr);
     }
   else
      s += ";;;;;;;;";
   return s + ";" + (r.tf >= HF_DAY ? IntegerToString(r.nearBreak) : "") + "\r\n";
  }

// lenh_vung.csv (InpHtf): mỗi lần vào lệnh thật của nhóm A và B: khung, loại, mã, lúc biết của vùng; nhóm A thêm nhãn trùng và vùng H
void WriteZoneRefs(string folder)
  {
   int h = FileOpen(folder + "lenh_vung.csv", FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON, 0, CP_UTF8);
   if(h == INVALID_HANDLE)
      return;
   FileWriteString(h, "# moi lan vao lenh that (nhom A: vung khung vao lenh, nhom B: vung khung lon, arm = ma trong nhom, nhu lenh.csv); khop_luc trong = bo vi dung lo cham ngay tick vao; vung dai dien khi nhieu vung cung phan ung: A uu tien vung trung, B vung khung lon nhat; biet_luc = luc vung dung duoc; dung_phia_luc = nen mo dung phia dau tien (nhom B); cham_dau_luc = gio mo nen cham dau (R4: nen M1 cham); trung 1 = nhom C (vung H: ma, khung, loai, day, dinh trong vung_htf.csv; d = 0,3 ATR M15; day_vung, dinh_vung, d ghi 6 so le), 0 = A khong trung; gan_gio_nghi (ngay/tuan): cuc tri in trong 15 phut sau mo cua hoac 30 phut truoc gio nghi (1), khong (0), khong biet (-1)\r\n");
   FileWriteString(h, "nhom;arm;o;chieu;pu_dong;khop_luc;khung_vung;loai_vung;ma_vung;day_vung;dinh_vung;biet_luc;dung_phia_luc;cham_dau_luc;trung;ma_H;khung_H;loai_H;day_H;dinh_H;d;trung_MSNR_H;gan_gio_nghi\r\n");
   for(int a = 0; a < ArraySize(g_arms); a++)
      FileWriteString(h, RefLine("A", a, g_arms[a], g_aref[a]));
   for(int a = 0; a < ArraySize(g_barms); a++)
      FileWriteString(h, RefLine("B", a, g_barms[a], g_bref[a]));
   FileClose(h);
  }

// Số liệu gom theo lần vào lệnh thật của một nhóm (A hoặc B): RC-T (tổng R, tổng giá, số lệnh đã xong), RC-D (R, giá), ngày, phần;
// bad = lần vào chưa xong khi hết dữ liệu
class CArmStats
  {
public:
   double            ctrlSum[], ctrlPx[], rcdR[], rcdPx[];
   int               ctrlCnt[], day[], part[];
   bool              bad[];
   int               nRcd, nBad, rctEnd;

   void              Init(const ArmInfo &arms[])
     {
      int na = ArraySize(arms);
      ArrayResize(ctrlSum, na);
      ArrayResize(ctrlCnt, na);
      ArrayResize(rcdR, na);
      ArrayResize(ctrlPx, na);
      ArrayResize(rcdPx, na);
      ArrayResize(bad, na);
      ArrayResize(day, na);
      ArrayResize(part, na);
      ArrayInitialize(ctrlSum, 0.0);
      ArrayInitialize(ctrlCnt, 0);
      ArrayInitialize(rcdR, EMPTY_VALUE);
      ArrayInitialize(ctrlPx, 0.0);
      ArrayInitialize(rcdPx, 0.0);
      ArrayInitialize(bad, false);
      for(int a = 0; a < na; a++)
        {
         day[a] = DayOf(arms[a].t);
         part[a] = PartOf(arms[a].t);
        }
      nRcd = 0;
      nBad = 0;
      rctEnd = 0;
     }

   // lệnh thật đã xong mà không có RC-T nào xong (không có trong cột thật − RC-T)
   int               NoCtrl(const ArmInfo &arms[]) const
     {
      int c = 0;
      for(int a = 0; a < ArraySize(arms); a++)
         if(arms[a].order >= 0 && !bad[a] && ctrlCnt[a] == 0)
            c++;
      return c;
     }
  };

// Mẫu của một dòng (ô × chọn chiều × phần)
class CRowData
  {
public:
   CSamples          rFill, dCtrl, dFlip;
   CSamples          pFill, pCtrl, pFlip;   // như trên nhưng theo giá mỗi 0,01 lot
   double            pairSum;               // tổng R lệnh thật trong nhóm ghép với RC-T
   int               armed, filled, wins;
                     CRowData(void) : pairSum(0.0), armed(0), filled(0), wins(0) {}
  };

// Gom lần vào của ô c, cách chọn chiều m, phần p; want: −1 mọi lần vào; 1 chỉ lần vào có nhãn trùng (nhóm C); 0 không trùng
void Collect(CRowData &d, const ArmInfo &arms[], CArmStats &S, int m, int c, int p, int want, const ZoneRef &refs[])
  {
   double sum, px;
   for(int a = 0; a < ArraySize(arms); a++)
     {
      if(arms[a].cell != c || S.part[a] != p || S.bad[a] || !ModeOk(m, arms[a]))
         continue;
      if(want >= 0 && (refs[a].tag.ovl == 1 ? 1 : 0) != want)
         continue;
      d.armed++;
      if(arms[a].order < 0)
         continue;
      d.filled++;
      double real;
      EntryVal(arms[a].order, InpSlip, sum, px, real);   // lần vào đã xong (bad = false)
      d.rFill.Add(S.day[a], real);
      d.pFill.Add(S.day[a], px);
      if(real > 0.0)
         d.wins++;
      if(S.ctrlCnt[a] > 0)
        {
         d.dCtrl.Add(S.day[a], real - S.ctrlSum[a] / S.ctrlCnt[a]);
         d.pCtrl.Add(S.day[a], px - S.ctrlPx[a] / S.ctrlCnt[a]);
         d.pairSum += real;
        }
      if(S.rcdR[a] != EMPTY_VALUE)
        {
         d.dFlip.Add(S.day[a], real - S.rcdR[a]);
         d.pFlip.Add(S.day[a], px - S.rcdPx[a]);
        }
     }
  }

// Phần sau cột "phần" của một dòng; st: 0 ít dữ liệu, 1 đạt, 2 không đạt. g1 < 0: ô không có X1 (x1R, x1P không dùng)
string RowText(CRowData &d, CSamples &x1R, CSamples &x1P, int g1, CSamples &x2R, CSamples &x2P, ulong seed, int &st)
  {
   st = 0;
   if(d.armed == 0)
      return StringFormat(" | %6d", 0);
   double lo = 0.0, hi = 0.0;
   bool ciOk = EnoughData(d.dCtrl) && d.dCtrl.CI(2000, seed, BootRank(2000, 0.05), lo, hi);
   string ctrlCi = ciOk ? "[" + Num(lo) + "; " + Num(hi) + "]" : "[ít dữ liệu]";   // cùng khoảng dùng cho kết luận
   st = d.filled < 100 ? 0 : (d.rFill.Mean() > 0.0 && ciOk && lo > 0.0 ? 1 : 2);
   string x1 = g1 < 0 ? "không có (R3 cần vùng)" : DiffText(d.rFill, x1R, seed + 5);
   string x2 = DiffText(d.rFill, x2R, seed + 7);
   int nPair = d.dCtrl.Count();
   // thêm kết quả và các hiệu theo giá mỗi 0,01 lot cạnh cột R (hiệu theo R với X1, X2 không so được khi SL dài khác nhau)
   string pxText = "", ctrlPxT = "", flipPxT = "";
   if(g_s24)
     {
      pxText = " | " + Num(d.pFill.Mean());
      ctrlPxT = "; giá " + Num(d.pCtrl.Mean()) + " " + CiText(d.pCtrl, seed + 2);
      flipPxT = "; giá " + Num(d.pFlip.Mean()) + " " + CiText(d.pFlip, seed + 4);
      if(g1 >= 0)
         x1 += "; giá " + DiffText(d.pFill, x1P, seed + 6);
      x2 += "; giá " + DiffText(d.pFill, x2P, seed + 8);
     }
   return StringFormat(" | %6d | %6d | %4.1f%% | %s %s%s | %s %s%s (ghép %d, thiếu %d, R ghép %s) | %s %s%s | %s | %s",
                       d.armed, d.filled, d.filled > 0 ? 100.0 * d.wins / d.filled : 0.0, Num(d.rFill.Mean()),
                       CiText(d.rFill, seed + 1), pxText, Num(d.dCtrl.Mean()), ctrlCi, ctrlPxT, nPair, d.filled - nPair,
                       nPair > 0 ? Num(d.pairSum / nPair) : "không có", Num(d.dFlip.Mean()), CiText(d.dFlip, seed + 3), flipPxT, x1, x2);
  }

double OnTester()
  {
   MqlTick t;
   SymbolInfoTick(_Symbol, t);
   g_sim.Finish(t);
   string folder = "PhanUngLab\\" + InpRunName + "_" + _Symbol + "_" + StringSubstr(EnumToString(_Period), 7) + "\\";
   WriteOrders(folder);
   if(g_htfOn)
     {
      WriteZoneRefs(folder);
      g_htf.WriteFiles(folder);
     }
   // gom đối chứng theo lần vào lệnh thật (nhóm A: SA, nhóm B: SB); lệnh thật chưa xong khi hết dữ liệu: bỏ cả lần vào
   int na = ArraySize(g_arms);
   CArmStats SA, SB;
   SA.Init(g_arms);
   SB.Init(g_barms);
   double sum, px, val;   // kết quả một lần vào (EntryVal): cả lệnh, mỗi 0,01 lot, R
   for(int k = 0; k < g_sim.n; k++)
     {
      int kind = g_sim.o[k].kind;
      if(kind == MK_X1 || kind == MK_X2 || g_sim.o[k].half == 2)   // nửa B tính cùng nửa A
         continue;
      int a = g_sim.o[k].arm;
      CArmStats *S = g_sim.o[k].cell >= CELL_COUNT ? GetPointer(SB) : GetPointer(SA);
      if(!EntryVal(k, InpSlip, sum, px, val))
        {
         if(kind == MK_REAL)
           {
            S.bad[a] = true;
            S.nBad++;
           }
         if(kind == MK_RCT)
            S.rctEnd++;
         continue;
        }
      if(kind == MK_RCT)
        {
         S.ctrlSum[a] += val;
         S.ctrlPx[a] += px;
         S.ctrlCnt[a]++;
        }
      if(kind == MK_RCD)
        {
         S.rcdR[a] = val;
         S.rcdPx[a] = px;
         S.nRcd++;
        }
     }
   // nhóm X theo cách chọn chiều × nhóm × phần: R (xs) và kết quả theo giá mỗi 0,01 lot
   CSamples xs[3 * XG_COUNT * 2], xsPx[3 * XG_COUNT * 2];
   int xWin[3 * XG_COUNT * 2];
   ArrayInitialize(xWin, 0);
   int nx1 = 0, nx2 = 0, xEnd1 = 0, xEnd2 = 0;
   for(int x = 0; x < ArraySize(g_xs); x++)
     {
      bool x1 = g_xs[x].cell < 3;
      if(x1)
         nx1++;
      else
         nx2++;
      if(!EntryVal(g_xs[x].order, InpSlip, sum, px, val))
        {
         if(x1)
            xEnd1++;
         else
            xEnd2++;
         continue;
        }
      int day = DayOf(g_xs[x].t), p = PartOf(g_xs[x].t);
      for(int m = 0; m < 3; m++)
        {
         if(!ModeOk(m, g_xs[x]))
            continue;
         int idx = (m * XG_COUNT + g_xs[x].cell) * 2 + p;
         xs[idx].Add(day, val);
         xsPx[idx].Add(day, px);
         if(val > 0.0)
            xWin[idx]++;
        }
     }
   // X2 nhóm B theo cách chọn chiều × loại vùng khung lớn × phần
   CSamples xsB[3 * HZ_COUNT * 2], xsBPx[3 * HZ_COUNT * 2];
   int xWinB[3 * HZ_COUNT * 2];
   ArrayInitialize(xWinB, 0);
   int bxEnd = 0;
   for(int x = 0; x < ArraySize(g_xsB); x++)
     {
      if(!EntryVal(g_xsB[x].order, InpSlip, sum, px, val))
        {
         bxEnd++;
         continue;
        }
      int day = DayOf(g_xsB[x].t), p = PartOf(g_xsB[x].t);
      for(int m = 0; m < 3; m++)
        {
         if(!ModeOk(m, g_xsB[x]))
            continue;
         int idx = (m * HZ_COUNT + g_xsB[x].cell - XG_COUNT) * 2 + p;
         xsB[idx].Add(day, val);
         xsBPx[idx].Add(day, px);
         if(val > 0.0)
            xWinB[idx]++;
        }
     }
   int placed = na - g_skipSl;
   int rctQueued = g_rct.n + g_rct1.n;   // việc chờ có ngày hẹn sau ngày cuối của dữ liệu
   int rctJobs = InpControls * placed;
   bool rctSumOk = rctJobs == g_rctPlaced + g_rctDrop + g_rctDropPart + rctQueued;
   string lines[];
   int nl = 0;
   ArrayResize(lines, 1500);
   lines[nl++] = StringFormat("%s %s %s: đệm trượt %s giá; %s; %d đối chứng thời điểm mỗi lệnh thật; tổng lệnh ảo %d; thời gian đo %d giây; lenh.csv không ghi RC-T trừ mẫu 1/%d",
                              InpRunName, _Symbol, EnumToString(_Period), DoubleToString(InpSlip, 2), ExitText(), InpControls,
                              g_sim.n, (int)((GetTickCount64() - g_t0) / 1000), RCT_SAMPLE);
   lines[nl++] = StringFormat("Lệnh thật: tìm thấy %d, bỏ %d vì dừng lỗ đã chạm ngay ở tick vào (giá nhảy qua mốc hoặc chênh lệch ≥ khoảng dừng lỗ), vào %d, trong đó %d chưa xong khi hết dữ liệu (không có trong các dòng); bỏ %d lần một ô có cả mua lẫn bán cùng nến. X1 %d, X2 %d lệnh, trong đó chưa xong khi hết dữ liệu X1 %d, X2 %d (không có trong các dòng); bỏ %d vì dừng lỗ đã chạm ngay ở tick vào, %d lần hai chiều cùng nến.",
                              na, g_skipSl, placed, SA.nBad, g_conflict, nx1, nx2, xEnd1, xEnd2, g_xSkipSl, g_xConflict);
   lines[nl++] = StringFormat("RC-T: %d việc (%d × %d lệnh thật đã vào) = đã vào %d + bỏ vì hết %d lần rút (sàn đóng / biến động khác / dừng lỗ chạm ngay tick vào) %d + bỏ vì sang phần dữ liệu khác %d + còn chờ khi hết dữ liệu (ngày hẹn sau ngày cuối) %d → %s; rút lại vì dừng lỗ chạm ngay tick vào %d lần; RC-T đã vào mà chưa xong khi hết dữ liệu %d; lệnh thật đã xong mà không có RC-T nào xong %d (không có trong cột thật − RC-T). RC-D đã xong %d. Tự kiểm tra: lệnh ảo bị dừng lỗ ngay ở tick vào %d (phải bằng 0).",
                              rctJobs, InpControls, placed, g_rctPlaced, RCT_TRIES, g_rctDrop, g_rctDropPart, rctQueued, rctSumOk ? "khớp" : "LỆCH",
                              g_rctSlRedraw, SA.rctEnd, SA.NoCtrl(g_arms), SA.nRcd, g_slAtEntry);
   // các dòng đầu về khung lớn (bắt đầu "HTF"), sau 3 dòng của nhóm A
   if(g_htfOn)
     {
      g_htf.W1Check();
      g_htf.HeaderLines(lines, nl);
      int nb = ArraySize(g_barms), placedB = nb - g_bSkipSl;
      int rctQueuedB = g_rctB.n + g_rct1B.n, rctJobsB = InpControls * placedB;
      bool okB = rctJobsB == g_bRctPlaced + g_bRctDrop + g_bRctDropPart + rctQueuedB;
      lines[nl++] = StringFormat("HTF nhóm B (vùng khung lớn): tìm thấy %d, bỏ %d vì dừng lỗ đã chạm ngay ở tick vào, vào %d, trong đó %d chưa xong khi hết dữ liệu (không có trong các dòng); bỏ %d lần một ô có cả mua lẫn bán cùng nến. X2 khung lớn %d lệnh, chưa xong khi hết dữ liệu %d; bỏ %d vì dừng lỗ đã chạm ngay ở tick vào, %d lần hai chiều cùng nến.",
                                 nb, g_bSkipSl, placedB, SB.nBad, g_bConflict, ArraySize(g_xsB), bxEnd, g_bxSkipSl, g_bxConflict);
      lines[nl++] = StringFormat("HTF RC-T nhóm B (dãy ngẫu nhiên riêng, nhóm A không đổi): %d việc (%d × %d) = đã vào %d + bỏ vì hết %d lần rút %d + bỏ vì sang phần dữ liệu khác %d + còn chờ khi hết dữ liệu %d → %s; rút lại vì dừng lỗ chạm ngay tick vào %d lần; RC-T đã vào mà chưa xong khi hết dữ liệu %d; lệnh nhóm B đã xong mà không có RC-T nào xong %d. RC-D nhóm B đã xong %d.",
                                 rctJobsB, InpControls, placedB, g_bRctPlaced, RCT_TRIES, g_bRctDrop, g_bRctDropPart, rctQueuedB, okB ? "khớp" : "LỆCH",
                                 g_bRctSlRedraw, SB.rctEnd, SB.NoCtrl(g_barms), SB.nRcd);
      int nC = 0, nN = 0, nMs = 0;
      for(int a = 0; a < na; a++)
        {
         if(g_arms[a].order < 0 || SA.bad[a])
            continue;
         if(g_aref[a].tag.ovl == 1)
            nC++;
         else
            nN++;
         if(g_aref[a].tag.msnr)
            nMs++;
        }
      lines[nl++] = StringFormat("HTF nhóm C / A không trùng (nhãn trên lệnh nhóm A, xét lúc mở nến chạm đầu; R4: nến M1 chạm): lệnh thật đã xong C %d, A không trùng %d; trong đó có cờ trùng MSNR khung lớn (chỉ ghi, không tính là trùng) %d.",
                                 nC, nN, nMs);
     }
   lines[nl++] = "Cột: chọn chiều | ô (vùng + phản ứng) | phần | lần vào | vào được | thắng (%) | R TB sau phí [KTC95] | thật − RC-T [KTC95] (ghép = số lệnh thật có RC-T đã xong, thiếu = vào được − ghép, R ghép = R TB sau phí của lệnh thật trong nhóm ghép) | thật − đảo chiều [KTC95] | thật − X1 [KTC95] | thật − X2 [KTC95] | phần này; dòng kiểm tra thêm kết luận chung (ĐẠT khi cả 2 phần: R > 0, thật − RC-T có KTC > 0, ≥ 100 lệnh). R4 chỉ có khi chạy M5.";
   if(g_s24)
      lines[nl - 1] = "Cột: chọn chiều | ô (vùng + phản ứng) | phần | lần vào | vào được | thắng (%) | R TB sau phí [KTC95] | giá TB mỗi 0,01 lot sau phí | thật − RC-T theo R [KTC95]; theo giá [KTC95] (ghép = số lệnh thật có RC-T đã xong, thiếu = vào được − ghép, R ghép = R TB sau phí của lệnh thật trong nhóm ghép) | thật − đảo chiều theo R [KTC95]; theo giá [KTC95] | thật − X1 theo R [KTC95]; theo giá [KTC95] | thật − X2 theo R [KTC95]; theo giá [KTC95] | phần này; dòng kiểm tra thêm kết luận chung (ĐẠT khi cả 2 phần: R > 0, thật − RC-T theo R có KTC > 0, ≥ 100 lệnh). R4 chỉ có khi chạy M5. Giá = kết quả mỗi 0,01 lot sau phí. " +
                      "RC-T, RC-D dùng đúng khoảng dừng lỗ của lệnh thật nên hiệu theo R so được; X1, X2 là nhóm riêng có khoảng dừng lỗ khác (X2: sau nến chạm, thường ngắn hơn) nên hiệu theo R với X1, X2 KHÔNG so được, xem hiệu theo giá.";
   string parts[2] = {"kham pha", "kiem tra"};
   string modes[3] = {"tin hieu", "xu huong H1", "EMA200 H1"};
   string stText[3] = {"ít dữ liệu", "đạt", "không đạt"};
   for(int m = 0; m < 3; m++)
      for(int c = 0; c < CELL_COUNT; c++)
        {
         int zt = c / R_COUNT, rr = c % R_COUNT;
         if(rr == RI_R4 && !g_r4)
            continue;
         string row[2];
         int st[2];
         int g1 = X1Of(rr);
         for(int p = 0; p < 2; p++)
           {
            CRowData d;
            Collect(d, g_arms, SA, m, c, p, -1, g_aref);
            ulong seed = RngMix(InpSeed, (ulong)(m * 1000 + c * 10 + p));
            int ix1 = (m * XG_COUNT + MathMax(g1, 0)) * 2 + p, ix2 = (m * XG_COUNT + 3 + zt) * 2 + p;   // ix1 chỉ dùng khi g1 ≥ 0
            row[p] = StringFormat("%-11s | %-20s | %-8s", modes[m], CellName(c), parts[p]) +
                     RowText(d, xs[ix1], xsPx[ix1], g1, xs[ix2], xsPx[ix2], seed, st[p]);
           }
         string verdict = st[0] == 1 && st[1] == 1 ? "ĐẠT" : (st[0] == 2 || st[1] == 2 ? "KHÔNG ĐẠT" : "ít dữ liệu");
         lines[nl++] = row[0] + " | " + stText[st[0]];
         lines[nl++] = row[1] + " | " + stText[st[1]] + "; chung: " + verdict;
        }
   lines[nl++] = "Nhóm X (SPEC §22.4). Cột: chọn chiều | nhóm | phần | số lệnh | thắng (%) | R TB sau phí [KTC95]" +
                 (g_s24 ? " | giá TB mỗi 0,01 lot sau phí" : "");
   for(int m = 0; m < 3; m++)
      for(int g = 0; g < XG_COUNT; g++)
        {
         if(g == 2 && !g_r4)
            continue;
         for(int p = 0; p < 2; p++)
           {
            int idx = (m * XG_COUNT + g) * 2 + p;
            int cnt = xs[idx].Count();
            lines[nl++] = StringFormat("%-11s | %-20s | %-8s | %6d | %4.1f%% | %s %s%s", modes[m], XName[g], parts[p], cnt,
                                       cnt > 0 ? 100.0 * xWin[idx] / cnt : 0.0, Num(xs[idx].Mean()),
                                       CiText(xs[idx], RngMix(InpSeed, (ulong)(50000 + idx))),
                                       g_s24 ? " | " + Num(xsPx[idx].Mean()) : "");
           }
        }
   if(g_htfOn)
     {
      int nCells = g_r4 ? CELL_COUNT : CELL_COUNT - ZT_COUNT, nBCells = g_r4 ? BCELL_COUNT : BCELL_COUNT - HZ_COUNT;
      lines[nl++] = StringFormat("HTF nhóm B, C, A không trùng (SPEC §25.5–25.6). Cột: nhóm | chọn chiều | ô | phần | rồi như nhóm A; dòng nhóm C thêm cột C − A không trùng theo R [KTC95]; theo giá [KTC95] (hai nhóm độc lập, lấy mẫu lại theo ngày 2.000 lần) trước cột phần này. Nhóm B: RC-T, RC-D của chính nó; X1 dùng chung của nhóm A (chỉ xét vùng khung vào lệnh); X2 là X2 của loại vùng khung lớn. C và A không trùng là lệnh nhóm A tách theo nhãn trùng (RC-T, RC-D, X1, X2 của nhóm A). Số ô đã đo: A %d, B %d, C %d, A không trùng %d, mỗi ô × 3 cách chọn chiều (tổng %d ô); càng nhiều ô càng dễ có ô đạt chỉ vì may.",
                                 nCells, nBCells, nCells, nCells, 3 * (3 * nCells + nBCells));
      for(int m = 0; m < 3; m++)
         for(int bc = 0; bc < BCELL_COUNT; bc++)
           {
            int bt = bc / R_COUNT, rr = bc % R_COUNT;
            if(rr == RI_R4 && !g_r4)
               continue;
            int c = CELL_COUNT + bc, g1 = X1Of(rr);
            string row[2];
            int st[2];
            for(int p = 0; p < 2; p++)
              {
               CRowData d;
               Collect(d, g_barms, SB, m, c, p, -1, g_bref);
               ulong seed = RngMix(InpSeed, (ulong)(100000 + m * 1000 + bc * 10 + p));
               int ix1 = (m * XG_COUNT + MathMax(g1, 0)) * 2 + p, ix2 = (m * HZ_COUNT + bt) * 2 + p;
               row[p] = StringFormat("%-13s | %-11s | %-24s | %-8s", "B", modes[m], CellName(c), parts[p]) +
                        RowText(d, xs[ix1], xsPx[ix1], g1, xsB[ix2], xsBPx[ix2], seed, st[p]);
              }
            string verdict = st[0] == 1 && st[1] == 1 ? "ĐẠT" : (st[0] == 2 || st[1] == 2 ? "KHÔNG ĐẠT" : "ít dữ liệu");
            lines[nl++] = row[0] + " | " + stText[st[0]];
            lines[nl++] = row[1] + " | " + stText[st[1]] + "; chung: " + verdict;
           }
      for(int m = 0; m < 3; m++)
         for(int c = 0; c < CELL_COUNT; c++)
           {
            int zt = c / R_COUNT, rr = c % R_COUNT;
            if(rr == RI_R4 && !g_r4)
               continue;
            int g1 = X1Of(rr);
            string rowC[2], rowN[2];
            int stC[2], stN[2];
            for(int p = 0; p < 2; p++)
              {
               CRowData dC, dN;
               Collect(dC, g_arms, SA, m, c, p, 1, g_aref);
               Collect(dN, g_arms, SA, m, c, p, 0, g_aref);
               ulong seedC = RngMix(InpSeed, (ulong)(200000 + m * 1000 + c * 10 + p)), seedN = RngMix(InpSeed, (ulong)(300000 + m * 1000 + c * 10 + p));
               int ix1 = (m * XG_COUNT + MathMax(g1, 0)) * 2 + p, ix2 = (m * XG_COUNT + 3 + zt) * 2 + p;
               rowC[p] = StringFormat("%-13s | %-11s | %-24s | %-8s", "C", modes[m], CellName(c), parts[p]) +
                         RowText(dC, xs[ix1], xsPx[ix1], g1, xs[ix2], xsPx[ix2], seedC, stC[p]);
               rowN[p] = StringFormat("%-13s | %-11s | %-24s | %-8s", "A không trùng", modes[m], CellName(c), parts[p]) +
                         RowText(dN, xs[ix1], xsPx[ix1], g1, xs[ix2], xsPx[ix2], seedN, stN[p]);
               rowC[p] += " | C − A không trùng theo R " + DiffText(dC.rFill, dN.rFill, seedC + 9) + "; theo giá " +
                          DiffText(dC.pFill, dN.pFill, seedC + 10);
              }
            string vC = stC[0] == 1 && stC[1] == 1 ? "ĐẠT" : (stC[0] == 2 || stC[1] == 2 ? "KHÔNG ĐẠT" : "ít dữ liệu");
            string vN = stN[0] == 1 && stN[1] == 1 ? "ĐẠT" : (stN[0] == 2 || stN[1] == 2 ? "KHÔNG ĐẠT" : "ít dữ liệu");
            lines[nl++] = rowC[0] + " | " + stText[stC[0]];
            lines[nl++] = rowC[1] + " | " + stText[stC[1]] + "; chung: " + vC;
            lines[nl++] = rowN[0] + " | " + stText[stN[0]];
            lines[nl++] = rowN[1] + " | " + stText[stN[1]] + "; chung: " + vN;
           }
      lines[nl++] = "HTF nhóm X2 khung lớn (chạm vùng khung lớn là vào). Cột: nhóm | chọn chiều | nhóm X | phần | số lệnh | thắng (%) | R TB sau phí [KTC95]" +
                    (g_s24 ? " | giá TB mỗi 0,01 lot sau phí" : "");
      for(int m = 0; m < 3; m++)
         for(int g = 0; g < HZ_COUNT; g++)
            for(int p = 0; p < 2; p++)
              {
               int idx = (m * HZ_COUNT + g) * 2 + p;
               int cnt = xsB[idx].Count();
               lines[nl++] = StringFormat("%-13s | %-11s | %-24s | %-8s | %6d | %4.1f%% | %s %s%s", "B", modes[m], XNameB[g], parts[p], cnt,
                                          cnt > 0 ? 100.0 * xWinB[idx] / cnt : 0.0, Num(xsB[idx].Mean()),
                                          CiText(xsB[idx], RngMix(InpSeed, (ulong)(60000 + idx))), g_s24 ? " | " + Num(xsBPx[idx].Mean()) : "");
              }
      // nhóm B theo khung của vùng đại diện (chỉ để xem, SPEC 25.6)
      lines[nl++] = "HTF nhóm B theo khung vùng (chỉ để xem, không dùng kết luận; chọn chiều 'tin hieu'; nhiều vùng cùng phản ứng thì tính cho vùng khung lớn nhất). Cột: ô | khung | khám phá: số lệnh, R TB sau phí, giá TB mỗi 0,01 lot sau phí | kiểm tra: như vậy";
      for(int bc = 0; bc < BCELL_COUNT; bc++)
        {
         int bt = bc / R_COUNT, rr = bc % R_COUNT;
         if(rr == RI_R4 && !g_r4)
            continue;
         int c = CELL_COUNT + bc;
         for(int tf = bt == HZ_DW ? HF_DAY : 0; tf <= (bt == HZ_DW ? HF_WEEK : HT_D1); tf++)
           {
            CSamples r[2], q[2];
            for(int a = 0; a < ArraySize(g_barms); a++)
              {
               if(g_barms[a].cell != c || g_bref[a].tf != tf || SB.bad[a] || g_barms[a].order < 0)
                  continue;
               EntryVal(g_barms[a].order, InpSlip, sum, px, val);
               r[SB.part[a]].Add(SB.day[a], val);
               q[SB.part[a]].Add(SB.day[a], px);
              }
            lines[nl++] = StringFormat("B theo khung | %-24s | %-4s | kham pha %5d lệnh, R %s, giá %s | kiem tra %5d lệnh, R %s, giá %s", CellName(c),
                                       HtfTfName[tf], r[0].Count(), Num(r[0].Mean()), Num(q[0].Mean()), r[1].Count(), Num(r[1].Mean()),
                                       Num(q[1].Mean()));
           }
        }
     }
   int fh = FileOpen(folder + "tong_ket.txt", FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON, 0, CP_UTF8);
   for(int k = 0; k < nl; k++)
     {
      Print("[PhanUngLab] ", lines[k]);
      if(fh != INVALID_HANDLE)
         FileWriteString(fh, lines[k] + "\r\n");
     }
   if(fh != INVALID_HANDLE)
      FileClose(fh);
   return 0.0;
  }
