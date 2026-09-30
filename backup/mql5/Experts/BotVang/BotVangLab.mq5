// BotVangLab: công cụ đo lợi thế điểm vào của BotVang bằng tick thật. KHÔNG đặt lệnh nào.
// Chạy trong Strategy Tester: "Every tick based on real ticks", XAUUSDm, khung M5.
// Kết quả: Common\Files\BotVangLab\<tên>_<KHAMPHA|KIEMTRA>_s<hạt giống>_<mã băm>\ (su_kien.csv, loi_lo_tam.csv, tong_ket.html).
#property copyright "BotVang"
#property version   "1.00"
#property description "Đo lợi thế điểm vào (SPEC §16). Không đặt lệnh."

#include <BotVang/Zones.mqh>
#include <BotVang/Bias.mqh>
#include <BotVang/Filters.mqh>
#include <BotVang/Signal.mqh>
#include <BotVang/LabFakes.mqh>
#include <BotVang/LabSim.mqh>
#include <BotVang/LabStats.mqh>
#include <BotVang/LabReport.mqh>

input group "Lần chạy"
input string   InpRunName = "goc";               // Tên bộ luật (đặt tên thư mục kết quả)
input int      InpSeed = 1;                      // Hạt giống ngẫu nhiên
input bool     InpOpenHoldout = false;           // Mở phần 30% cuối (phải khóa trước)
input bool     InpWriteLock = false;             // Ghi khóa các tập luật ở InpLockSets sau lần chạy này
input string   InpLockSets = "GOC";              // Mã tập luật để khóa, cách nhau bởi dấu phẩy
input double   InpCost = 0.5;                    // Chi phí ngoài chênh lệch c (theo giá) dùng để kết luận
input int      InpWarmupDays = 60;               // Số ngày lịch sử nạp trước ngày bắt đầu
input int      InpPairDays = 7;                  // Cửa sổ tìm sự kiện giả đối chứng: số ngày lịch (vùng M15; khung lớn gấp đôi)
input int      InpFakeMult = 4;                  // Hệ số nhân số vùng giả (5/10/20/10 × hệ số) để kho ghép cặp đủ lớn
input bool     InpSelfTest = true;               // Tự kiểm tra công thức thống kê khi khởi động
input bool     InpDraw = true;                   // Vẽ sự kiện khi chạy trực quan
input group "Mốc dữ liệu (giờ VN)"
input datetime InpHalfVn = D'2026.04.06 00:00';  // Bắt đầu nửa sau của phần 70% (70b)
input datetime InpCutVn = D'2026.07.06 00:00';   // Bắt đầu phần 30% cuối
input int      InpVnOffset = 7;                  // Giờ VN = giờ sàn + số giờ này
input bool     InpSpecSummer = true;             // Lịch phiên trong terminal đang theo giờ hè Mỹ (ngày mùa đông dời 1 giờ)
input group "Luật vùng"
input ENUM_BIAS_MODE InpBiasMode = BIAS_H4_H1;   // Hướng lớn
input bool     InpFlipNeedsAway = true;          // [GỐC] sau lật phải rời xa rồi mới tính chạm; false = biến thể "chạm ngay"
input double   InpAwayAtr = 1.0;                 // Rời xa >= x × biến động khung vùng
input int      InpMinTouchGapBars = 0;           // [Ứng viên] 2 lần chạm cách nhau >= số nến M5 (0 = tắt)
input double   InpRetestAwayAtrM5 = 0.0;         // [Ứng viên] sau lật phải rời >= x × ATR(M5) (0 = tắt)
input int      InpRetestMinBars = 0;             // [Ứng viên] sau lật phải qua >= số nến này mới tính chạm
input int      InpFailedFlipBars = 0;            // [Ứng viên] hủy lật nếu trong số nến này đóng quay lại dải (0 = tắt)
input bool     InpGapBaseBreakout = false;       // [Ứng viên] lọc Gap kiểu đế + thoát
input int      InpExpireM15Hours = 0;            // [Ứng viên] vùng M15 hết hạn sau số giờ (0 = không)
input int      InpExpireHtfDays = 0;             // [Ứng viên] vùng khung lớn hết hạn sau số ngày (0 = không)
input group "Vào lệnh"
input int      InpMinEntryScore = 4;             // Điểm tối thiểu để vào
input int      InpStrongScore = 6;               // Điểm của cản mạnh
input double   InpMinRoomB = 2.0;                // Khoảng tới cản mạnh đối diện >= x × B
input double   InpStepAtrMult = 0.8;             // B = max(x × ATR(M5), ...)
input double   InpStepMinSpreadMult = 5.0;       // ... , y × chênh lệch)
input group "Bộ lọc"
input bool     InpTimeFilter = true;             // Lọc giờ chạy
input int      InpStartMinVn = 840;              // Giờ chạy từ phút (VN)
input int      InpEndMinVn = 1440;               // tới phút (VN), 1440 = 24:00
input int      InpBreakCloseMin = 30;            // Không vào khi còn <= số phút tới giờ nghỉ của sàn
input int      InpAfterOpenMin = 15;             // Không vào khi sàn mới mở lại chưa quá số phút
input double   InpMaxSpread = 0.5;               // Chênh lệch tối đa (giá)
input bool     InpNewsFilter = true;             // Lọc tin mạnh USD (tester: file news_usd.csv)
input int      InpNewsBefore = 5;                // Phút trước tin
input int      InpNewsAfter = 10;                // Phút sau tin
input int      InpFomcAfter = 60;                // Phút sau quyết định lãi suất Fed / họp báo

CZones      g_zones;
CFakeZones  g_fakes;
CLabSim     g_sim;
CNews       g_news;
CLabReport  g_rep;
MarketCfg   g_mcfg;
ZoneRules   g_rules;
int         g_hAtrM5 = INVALID_HANDLE;
bool        g_ready = false;
bool        g_stopping = false;
bool        g_stopSent = false;
datetime    g_lastBar = 0;
datetime    g_lastH1 = 0;
datetime    g_lastTick = 0;
MqlTick     g_tick;
int         g_biasH4 = 0, g_biasH1 = 0, g_bias = 0;
double      g_spreads[];
int         g_nSpread = 0;
double      g_atrM5 = 0.0;
bool        g_lowVol = false;
datetime    g_half, g_cut;
int         g_botOpen = -1;
string      g_params, g_hash, g_folder, g_mode;
int         g_lockedCount = 1;
string      g_lockedSets = "";
int         g_realZones = 0, g_unconfirmed = 0, g_noEntry = 0;
double      g_ratioSum = 0.0;
int         g_ratioN = 0;
datetime    g_firstEventDay = 0;

//+------------------------------------------------------------------+
string Sha256(const string s)
  {
   uchar data[], key[], out[];
   int n = StringToCharArray(s, data, 0, -1, CP_UTF8);
   ArrayResize(data, MathMax(0, n - 1));
   if(CryptEncode(CRYPT_HASH_SHA256, data, key, out) <= 0)
      return "";
   string h = "";
   for(int i = 0; i < ArraySize(out); i++)
      h += StringFormat("%02x", out[i]);
   return h;
  }

// Mọi tham số ảnh hưởng tới kết quả (không gồm tên, công tắc mở/khóa, vẽ)
string ParamString()
  {
   // Ký hiệu nằm trong mã: khóa luật của ký hiệu này không dùng được cho ký hiệu khác
   return StringFormat("sym=%s;lab=1;pair=%d;fake=%d;seed=%d;cost=%.3f;warm=%d;half=%s;cut=%s;vn=%d;bias=%d;flipAway=%d;away=%.3f;gap=%d;"
                       "retAway=%.3f;retBars=%d;failFlip=%d;gapBB=%d;expM15=%d;expHtf=%d;score=%d;strong=%d;room=%.3f;"
                       "stepAtr=%.3f;stepSp=%.3f;tf=%d;start=%d;end=%d;brk=%d;open=%d;spread=%.3f;news=%d;nb=%d;na=%d;nf=%d",
                       _Symbol, InpPairDays, InpFakeMult, InpSeed, InpCost, InpWarmupDays, TimeToString(InpHalfVn), TimeToString(InpCutVn), InpVnOffset,
                       (int)InpBiasMode, (int)InpFlipNeedsAway, InpAwayAtr, InpMinTouchGapBars, InpRetestAwayAtrM5,
                       InpRetestMinBars, InpFailedFlipBars, (int)InpGapBaseBreakout, InpExpireM15Hours, InpExpireHtfDays,
                       InpMinEntryScore, InpStrongScore, InpMinRoomB, InpStepAtrMult, InpStepMinSpreadMult, (int)InpTimeFilter,
                       InpStartMinVn, InpEndMinVn, InpBreakCloseMin, InpAfterOpenMin, InpMaxSpread, (int)InpNewsFilter,
                       InpNewsBefore, InpNewsAfter, InpFomcAfter);
  }

// Tự kiểm tra công thức bằng các ví dụ đã biết đáp án
bool Check(bool cond, const string name, string &failed)
  {
   if(!cond)
      failed += name + " ";
   return cond;
  }

bool SelfTest()
  {
   string failed = "";
   double lo, hi;
   Wilson(50, 100, 1.959964, lo, hi);
   Check(MathAbs(lo - 0.4038) < 0.0005 && MathAbs(hi - 0.5962) < 0.0005, "wilson50/100", failed);
   Wilson(0, 10, 1.959964, lo, hi);
   Check(MathAbs(lo) < 1e-9 && MathAbs(hi - 0.2775) < 0.0005, "wilson0/10", failed);
   Wilson(10, 10, 1.959964, lo, hi);
   Check(MathAbs(lo - 0.7225) < 0.0005 && MathAbs(hi - 1.0) < 1e-9, "wilson10/10", failed);
   Check(MathAbs(BreakEvenP(2.0, 0.5, 1) - 0.625) < 1e-9 && MathAbs(BreakEvenP(2.0, 0.5, 2) - 0.416667) < 1e-5
         && MathAbs(BreakEvenP(2.0, 0.5, 3) - 0.3125) < 1e-9, "hoavon", failed);
   Check(MathAbs(NormInv(0.975) - 1.959964) < 1e-5 && MathAbs(NormInv(1.0 - 0.05 / 6.0) - 2.393980) < 1e-4, "norminv", failed);
   Check(BootRank(2000, 0.05) == 50 && BootRank(2000, 0.05 / 3.0) == 17, "bootrank", failed);
   CSamples s;
   for(int d = 0; d < 30; d++)
     {
      s.Add(20260100 + d, 1.0);
      s.Add(20260100 + d, 0.0);
     }
   Check(s.CI(2000, 7, 50, lo, hi) && MathAbs(lo - 0.5) < 1e-12 && MathAbs(hi - 0.5) < 1e-12 && s.Days() == 30, "bootstrap", failed);
   CRng a, b;
   a.Seed(42);
   b.Seed(42);
   bool same = true;
   for(int i = 0; i < 5; i++)
     {
      double u = a.Uniform();
      same &= u == b.Uniform() && u >= 0.0 && u < 1.0;
     }
   Check(same, "rng", failed);
   Print("[BotVangLab] TỰ KIỂM TRA CÔNG THỨC: ", failed == "" ? "ĐẠT" : "KHÔNG ĐẠT: " + failed);
   return failed == "";
  }

// Đọc file khóa: phải có dòng khóa cho đúng mã băm tham số này thì mới được mở phần 30%
bool ReadLocks()
  {
   int h = FileOpen("BotVangLab\\khoa_ung_vien.csv", FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_SHARE_READ);
   if(h == INVALID_HANDLE)
     {
      Print("[BotVangLab] CHƯA KHÓA ỨNG VIÊN NÀO: không mở phần 30%.");
      return false;
     }
   // Đếm các tập luật khác nhau đã khóa cho đúng mã băm này (bỏ dòng trùng); tối đa 3
   int total = 0;
   while(!FileIsEnding(h))
     {
      string f[];
      if(StringSplit(FileReadString(h), ';', f) < 3 || f[1] != g_hash || StringFind("," + g_lockedSets, "," + f[2] + ",") >= 0)
         continue;
      g_lockedSets += f[2] + ",";
      total++;
     }
   FileClose(h);
   if(total == 0)
     {
      Print("[BotVangLab] Bộ tham số này chưa được khóa (mã ", StringSubstr(g_hash, 0, 8), "): không mở phần 30%.");
      return false;
     }
   if(total > 3)
     {
      Print("[BotVangLab] Khóa ", total, " tập luật, quá 3 (§16.8): không mở phần 30%.");
      return false;
     }
   g_lockedCount = total;
   return true;
  }

void AppendLine(const string file, const string line)
  {
   int h = FileOpen(file, FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_SHARE_READ);
   if(h == INVALID_HANDLE)
     {
      Print("[BotVangLab] khong_ghi_duoc ", file, " err=", GetLastError());
      return;
     }
   FileSeek(h, 0, SEEK_END);
   FileWriteString(h, line + "\r\n");
   FileClose(h);
  }

// Số bộ tham số khác nhau đã chạy khám phá (tính cả lần này)
int CountExplorations()
  {
   string seen = "|" + (InpOpenHoldout ? "" : g_hash) + "|";
   int n = InpOpenHoldout ? 0 : 1;
   int h = FileOpen("BotVangLab\\nhat_ky_chay.csv", FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_SHARE_READ);
   if(h == INVALID_HANDLE)
      return n;
   while(!FileIsEnding(h))
     {
      string f[];
      if(StringSplit(FileReadString(h), ';', f) < 3 || f[2] != "KHAMPHA")
         continue;
      if(StringFind(seen, "|" + f[1] + "|") < 0)
        {
         seen += f[1] + "|";
         n++;
        }
     }
   FileClose(h);
   return n;
  }

double AtrM5At(datetime t)
  {
   double b[];
   return CopyBuffer(g_hAtrM5, 0, t - 1, 1, b) == 1 ? b[0] : 0.0;
  }

int VnDay(datetime server)
  {
   MqlDateTime d;
   TimeToStruct(server + InpVnOffset * 3600, d);
   return d.year * 10000 + d.mon * 100 + d.day;
  }

// Phiên theo giờ sàn cố định: Á 21–07, Âu 07–12, Mỹ 12–21
int SessionOf(datetime server)
  {
   MqlDateTime d;
   TimeToStruct(server, d);
   return (d.hour >= 21 || d.hour < 7) ? 0 : (d.hour < 12 ? 1 : 2);
  }

int PartOf(datetime server) { return server < g_half ? 0 : (server < g_cut ? 1 : 2); }

int Rel(int bias, int dir) { return bias == 0 ? 0 : (bias == dir ? 1 : -1); }

// Số tròn trong dải vùng (mở rộng tol): 2 = có xx00, 1 = chỉ xx50, 0 = không
int RoundFlag(double lo, double hi, double atr)
  {
   double tol = 0.1 * atr;
   double a = lo - tol, b = hi + tol;
   if(MathCeil(a / 100.0) * 100.0 <= b)
      return 2;
   return MathCeil(a / 50.0) * 50.0 <= b ? 1 : 0;
  }

// Số vùng thật khác còn sống có đường mức cách <= 0,3 × ATR(M15), tối đa 3
int ConfCount(const Zone &z, double atr15)
  {
   int c = 0;
   for(int j = 0; j < g_zones.count && c < 3; j++)
      if(g_zones.zones[j].id != z.id && !g_zones.zones[j].dead
         && MathAbs(g_zones.zones[j].level - z.level) <= 0.3 * atr15)
         c++;
   return c;
  }

// Lúc lệnh ảo phải đóng: 24:00 VN nếu vào trong giờ chạy; ngoài giờ thì tối đa 288 nến; và 30 phút trước giờ nghỉ của sàn
datetime CloseAt(datetime at, bool inWindow, datetime barOpen, int &reason)
  {
   datetime c;
   if(inWindow)
     {
      long vn = (long)at + InpVnOffset * 3600;
      c = (datetime)((vn / 86400 + 1) * 86400 - InpVnOffset * 3600);
      reason = EXIT_DAYEND;
     }
   else
     {
      c = barOpen + 288 * 300;
      reason = EXIT_MAXBARS;
     }
   int toEnd, fromStart;
   if(SessionAt(g_mcfg, _Symbol, at, toEnd, fromStart))
     {
      datetime s = at + (toEnd - InpBreakCloseMin) * 60;
      if(s < c)
        {
         c = s;
         reason = EXIT_SESSION;
        }
     }
   return c;
  }

void SetOpp(LabEvent &e, double bid)
  {
   double dist;
   int j = g_zones.NearestStrong(e.dir, bid, InpStrongScore, dist);
   e.oppEdge = j >= 0 ? (e.dir > 0 ? g_zones.zones[j].lo : g_zones.zones[j].hi) : 0.0;
   e.oppLo = j >= 0 ? g_zones.zones[j].lo : 0.0;
   e.oppHi = j >= 0 ? g_zones.zones[j].hi : 0.0;
  }

void Draw(const LabEvent &e)
  {
   if(!InpDraw || !MQLInfoInteger(MQL_VISUAL_MODE) || e.fake || e.type == EV_REVERSE)
      return;
   string name = "BVL_" + (string)e.id;
   color c = e.flags == 0 ? (e.dir > 0 ? clrLime : clrRed) : clrGray;
   ObjectCreate(0, name + "_z", OBJ_RECTANGLE, 0, e.zoneCreated, e.hi, e.touchTime, e.lo);
   ObjectSetInteger(0, name + "_z", OBJPROP_COLOR, e.dir > 0 ? clrDarkGreen : clrMaroon);
   ObjectSetInteger(0, name + "_z", OBJPROP_FILL, true);
   ObjectSetInteger(0, name + "_z", OBJPROP_BACK, true);
   ObjectCreate(0, name, e.dir > 0 ? OBJ_ARROW_BUY : OBJ_ARROW_SELL, 0, e.touchTime, e.entry);
   ObjectSetInteger(0, name, OBJPROP_COLOR, c);
   string kinds[4] = {"A/V", "Gap", "Đỉnh/đáy xoay", "Đỉnh/đáy ngày"};
   ObjectSetString(0, name, OBJPROP_TOOLTIP, TfName(e.tf) + " " + kinds[(int)e.kind] + " điểm " + (string)e.scorePre
                   + " lọc " + (string)e.flags);
  }

// Tạo sự kiện vào lệnh từ một lần chạm đầu đã xác nhận
void CreateEvent(const Zone &z, int type, int dir, int dup, bool fake, const MqlRates &bar, const MqlTick &t, double spreadMed, bool newsWin)
  {
   LabEvent e;
   LabEventReset(e);
   datetime now = bar.time + PeriodSeconds(PERIOD_M5);
   double atr15 = g_zones.AtrM15(now);
   e.fake = fake;
   e.type = type;
   e.zoneId = z.id;
   e.parentId = z.parent;
   e.tf = z.tf;
   e.kind = z.kind;
   e.level = z.level;
   e.lo = z.lo;
   e.hi = z.hi;
   e.zoneAtr = z.atr;
   e.zoneCreated = z.created;
   e.touchTime = now;
   e.dir = dir;
   e.scorePre = z.score;
   e.scorePost = ZoneScore(z, g_zones.zones, g_zones.count, atr15, g_zones.DayStart());
   e.overlapReal = fake && FakeOverlapsReal(z, g_zones.zones, g_zones.count);
   e.conf = ConfCount(z, atr15);
   e.bouncesBeforeFlip = z.bouncesBeforeFlip;
   e.barsFromFlip = z.flips == 1 ? z.barsSinceFlip : 0;
   e.barsFromCreate = z.barsAlive;
   e.dupCount = dup;
   e.strongOrigin = z.strongOrigin;
   e.round = RoundFlag(z.lo, z.hi, z.atr);
   double range = bar.high - bar.low;
   e.closePos = range > 0.0 ? (dir > 0 ? (bar.close - bar.low) / range : (bar.high - bar.close) / range) : 0.5;
   e.bias = g_bias;
   e.biasRel = Rel(g_bias, dir);
   e.session = SessionOf(bar.time);
   e.part = PartOf(now);
   e.vnDay = VnDay(now);
   MqlDateTime vt;
   TimeToStruct(now + InpVnOffset * 3600, vt);
   e.vnMinute = vt.hour * 60 + vt.min;
   e.atrM5 = g_atrM5;
   e.spreadTouch = spreadMed;
   e.spreadEntry = t.ask - t.bid;
   e.entryBarOpen = now;
   e.entryMsc = t.time_msc;
   e.entry = dir > 0 ? t.ask : t.bid;
   e.B = StepB(g_atrM5, e.spreadEntry, InpStepAtrMult, InpStepMinSpreadMult, SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE),
               _Digits, e.bBySpread);
   e.chaseB = e.B > 0.0 ? (dir > 0 ? (e.entry - z.hi) / e.B : (z.lo - e.entry) / e.B) : 0.0;
   // Bộ lọc tầng 2
   if(e.biasRel != 1)
      e.flags |= FL_BIAS;
   if(!fake && e.scorePre < InpMinEntryScore)
      e.flags |= FL_SCORE;
   if(!RoomOk(g_zones, dir, t.bid, e.spreadEntry, e.B, InpStrongScore, InpMinRoomB))
      e.flags |= FL_ROOM;
   e.flags |= MarketFlags(g_mcfg, _Symbol, t.time, e.spreadEntry, g_news.available, newsWin);
   if(t.time - now >= 1800 || e.B <= 0.0)
     {
      e.flags |= FL_NOENTRY;
      g_noEntry++;
     }
   // Cờ ứng viên
   if(e.bBySpread)
      e.cand |= CF_BSPREAD;
   if(e.closePos < 0.6)
      e.cand |= CF_CLOSEPOS;
   if(e.chaseB > 1.2)
      e.cand |= CF_CHASE;
   if(type == EV_FLIPPED && z.barsSinceFlip > 24)
      e.cand |= CF_WAIT;
   if(g_lowVol)
      e.cand |= CF_LOWVOL;
   if(Rel(g_biasH1, dir) != 1)
      e.cand |= CF_BIAS_H1;
   if(Rel(g_biasH4, dir) != 1)
      e.cand |= CF_BIAS_H4;
   // Lệnh ảo
   e.closeAt = CloseAt(t.time, (e.flags & FL_TIME) == 0, now, e.closeReason);
   SetOpp(e, t.bid);
   // Chuỗi lệnh của bot: luật gốc, vùng thật; bận nếu lệnh trước chưa đóng
   if(!fake && type == EV_FLIPPED && e.flags == 0)
     {
      e.chosen = true;
      e.busy = g_botOpen >= 0 && !g_sim.ev[g_botOpen].simDone;
     }
   bool measure = (e.flags & FL_NOENTRY) == 0;
   int idx = g_sim.Add(e, measure);
   if(e.chosen && !e.busy && measure)
      g_botOpen = idx;
   Draw(g_sim.ev[idx]);
  }

// Gom các lần chạm đầu đã xác nhận ở nến vừa đóng thành sự kiện: mỗi (loại, chiều) một sự kiện, gán cho vùng bot sẽ chọn
void Collect(const Zone &evz[], const int &evf[], int cnt, bool fake, const MqlRates &bar, const MqlTick &t, double spreadMed, bool newsWin)
  {
   SignalPick picks[];
   int unconfirmed;
   int n = PickSignals(evz, evf, cnt, bar, picks, unconfirmed);
   if(!fake)
      g_unconfirmed += unconfirmed;
   for(int i = 0; i < n; i++)
      CreateEvent(picks[i].z, picks[i].type, picks[i].dir, picks[i].dup, fake, bar, t, spreadMed, newsWin);
  }

// Vùng giả: mỗi bộ bản sao (1..n) là một "thế giới giả" có cùng mật độ với vùng thật, nên gom sự kiện riêng từng bộ.
// Điểm của vùng giả tính như vùng thật, theo trạng thái trước nến chạm (chưa chạm), để chọn vùng giống cách chọn vùng thật.
void CollectFakes(const MqlRates &bar, const MqlTick &t, double spreadMed, bool newsWin)
  {
   datetime now = bar.time + PeriodSeconds(PERIOD_M5);
   double atr15 = g_zones.AtrM15(now);
   for(int c = 1; c <= g_fakes.MaxCopies(); c++)
     {
      Zone sub[];
      int flags[];
      int m = 0;
      for(int i = 0; i < g_fakes.evCount; i++)
        {
         if(g_fakes.evZone[i].copy != c)
            continue;
         ArrayResize(sub, m + 1, 16);
         ArrayResize(flags, m + 1, 16);
         sub[m] = g_fakes.evZone[i];
         Zone pre = sub[m];
         pre.touches = 0;
         sub[m].score = ZoneScore(pre, g_zones.zones, g_zones.count, atr15, g_zones.DayStart());
         flags[m] = g_fakes.evFlags[i];
         m++;
        }
      if(m > 0)
         Collect(sub, flags, m, true, bar, t, spreadMed, newsWin);
     }
  }

// Sự kiện đảo chiều: lệnh ảo vừa dính dừng lỗ → đo lệnh ngược chiều đặt đúng tại giá dừng lỗ
void CreateReverse(int srcIdx, const MqlTick &t, bool newsWin)
  {
   LabEvent src = g_sim.ev[srcIdx];
   if(src.type == EV_REVERSE || src.bNext <= 0.0)
      return;
   LabEvent r;
   LabEventReset(r);
   r.fake = src.fake;
   r.type = EV_REVERSE;
   r.src = srcIdx;
   r.zoneId = src.zoneId;
   r.parentId = src.parentId;
   r.tf = src.tf;
   r.kind = src.kind;
   r.level = src.level;
   r.lo = src.lo;
   r.hi = src.hi;
   r.zoneAtr = src.zoneAtr;
   r.zoneCreated = src.zoneCreated;
   r.touchTime = t.time;
   r.dir = -src.dir;
   r.scorePre = src.scorePre;
   r.conf = src.conf;
   r.bouncesBeforeFlip = src.bouncesBeforeFlip;
   r.round = src.round;
   r.bias = g_bias;
   r.biasRel = Rel(g_bias, r.dir);
   r.session = SessionOf(t.time);
   r.part = PartOf(t.time);
   r.vnDay = VnDay(t.time);
   MqlDateTime vt;
   TimeToStruct(t.time + InpVnOffset * 3600, vt);
   r.vnMinute = vt.hour * 60 + vt.min;
   r.atrM5 = g_atrM5;
   r.spreadEntry = t.ask - t.bid;
   r.spreadTouch = r.spreadEntry;
   r.entryBarOpen = (datetime)((long)t.time / 300 * 300);
   r.entryMsc = t.time_msc;
   r.entry = src.exitPrice;
   r.B = src.bNext;
   r.flags = MarketFlags(g_mcfg, _Symbol, t.time, r.spreadEntry, g_news.available, newsWin);
   if(g_zones.InsideStrong(r.entry, InpStrongScore))
      r.rev |= RF_SL_IN_STRONG;
   if(src.barsInsideOpp > 6)
      r.rev |= RF_INSIDE6;
   int recent = 3 * PeriodSeconds(PERIOD_M5);
   bool pushed = (g_zones.lastBreakDir == r.dir && t.time - g_zones.lastBreakTime <= recent + 300)
                 || (g_zones.lastRejectDir == r.dir && t.time - g_zones.lastRejectTime <= recent + 300);
   if(r.dir != g_bias && !pushed)
      r.rev |= RF_AGAINST;
   if(Rel(g_biasH1, r.dir) != 1)
      r.cand |= CF_BIAS_H1;
   if(Rel(g_biasH4, r.dir) != 1)
      r.cand |= CF_BIAS_H4;
   r.closeAt = CloseAt(t.time, (r.flags & FL_TIME) == 0, r.entryBarOpen, r.closeReason);
   SetOpp(r, t.bid);
   g_sim.Add(r, true);
  }

double SpreadMedian()
  {
   if(g_nSpread == 0)
      return 0.0;
   double s[];
   ArrayCopy(s, g_spreads, 0, 0, g_nSpread);
   ArraySort(s);
   return g_nSpread % 2 == 1 ? s[g_nSpread / 2] : (s[g_nSpread / 2 - 1] + s[g_nSpread / 2]) / 2.0;
  }

// Khởi động: cho 60 ngày nến M5 trước ngày bắt đầu chạy qua vùng thật và vùng giả theo đúng thứ tự thời gian
bool Warmup()
  {
   MqlRates m5[];
   int n = CopyRates(_Symbol, PERIOD_M5, 0, InpWarmupDays * 288 + 1, m5);
   if(n < 1000)
     {
      Print("[BotVangLab] thieu_lich_su nen M5: ", n);
      return false;
     }
   g_zones.Start(m5[0].time);
   for(int i = 1; i < n; i++)
     {
      datetime at = m5[i].time;
      g_zones.Step(at, 0.0, 0.0, InpStrongScore, false);
      for(int j = 0; j < g_zones.newCount; j++)
         g_fakes.Spawn(g_zones.newZones[j], g_zones.zones, g_zones.count, m5[i - 1].close);
      g_realZones += g_zones.newCount;
      g_fakes.Step(m5[i - 1], AtrM5At(at));
      g_fakes.Prune(m5[i - 1].close, at, g_zones.AtrH1(at));
     }
   g_zones.RefreshScores(m5[n - 1].time);
   g_lastBar = m5[n - 1].time;
   g_atrM5 = AtrM5At(g_lastBar);
   g_biasH4 = StructureBias(_Symbol, PERIOD_H4);
   g_biasH1 = StructureBias(_Symbol, PERIOD_H1);
   g_bias = CombinedBias(g_biasH4, g_biasH1, InpBiasMode);
   g_lastH1 = (datetime)((long)g_lastBar / 3600 * 3600);
   PrintFormat("[BotVangLab] khởi động xong: %d nến M5 từ %s; vùng thật %d, vùng giả %d (không đặt được %d); lỗi lấy dữ liệu %d",
               n - 1, TimeToString(m5[0].time), g_zones.count, g_fakes.count, g_fakes.notPlaced, g_zones.loadErrors);
   return true;
  }

void OnNewBar(datetime bar, const MqlTick &t, bool newsWin)
  {
   double med = SpreadMedian();
   g_nSpread = 0;
   MqlRates b[];
   if(CopyRates(_Symbol, PERIOD_M5, bar - 1, 1, b) != 1)
      return;
   g_atrM5 = AtrM5At(bar);
   double a[];
   if(CopyBuffer(g_hAtrM5, 0, bar - 1, 288, a) == 288)
     {
      double s = 0.0;
      for(int i = 0; i < 288; i++)
         s += a[i];
      g_lowVol = g_atrM5 < 0.5 * s / 288.0;
     }
   datetime h1 = (datetime)((long)bar / 3600 * 3600);
   if(h1 != g_lastH1)
     {
      g_lastH1 = h1;
      g_biasH4 = StructureBias(_Symbol, PERIOD_H4);
      g_biasH1 = StructureBias(_Symbol, PERIOD_H1);
      g_bias = CombinedBias(g_biasH4, g_biasH1, InpBiasMode);
      double ah1 = g_zones.AtrH1(bar);
      if(ah1 > 0.0 && g_atrM5 > 0.0)
        {
         g_ratioSum += ah1 / g_atrM5;
         g_ratioN++;
        }
     }
   g_zones.OnNewM5(bar, RecentSwingM5(_Symbol, true), RecentSwingM5(_Symbol, false), InpStrongScore);
   for(int j = 0; j < g_zones.newCount; j++)
      g_fakes.Spawn(g_zones.newZones[j], g_zones.zones, g_zones.count, b[0].close);
   g_realZones += g_zones.newCount;
   g_fakes.Step(b[0], g_atrM5);
   g_fakes.Prune(b[0].close, bar, g_zones.AtrH1(bar));
   // cản mạnh đối diện của các lệnh ảo đang chạy, và số nến liền nhau giá đóng trong dải cản
   for(int k = 0; k < g_sim.nActive; k++)
     {
      int i = g_sim.active[k];
      if(g_sim.ev[i].simDone)
         continue;
      bool inside = g_sim.ev[i].oppEdge > 0.0 && b[0].close >= g_sim.ev[i].oppLo && b[0].close <= g_sim.ev[i].oppHi;
      g_sim.ev[i].barsInsideOpp = inside ? g_sim.ev[i].barsInsideOpp + 1 : 0;
      SetOpp(g_sim.ev[i], t.bid);
     }
   if(g_stopping)
      return;
   Collect(g_zones.evZone, g_zones.evFlags, g_zones.evCount, false, b[0], t, med, newsWin);
   CollectFakes(b[0], t, med, newsWin);
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_OPTIMIZATION))
     {
      Print("[BotVangLab] Chỉ chạy trong Strategy Tester (không tối ưu).");
      return INIT_FAILED;
     }
   if(InpSelfTest && !SelfTest())
      return INIT_FAILED;
   ZoneRulesDefault(g_rules);
   g_rules.awayAtr = InpAwayAtr;
   g_rules.flipNeedsAway = InpFlipNeedsAway;
   g_rules.minTouchGapBars = InpMinTouchGapBars;
   g_rules.retestAwayAtrM5 = InpRetestAwayAtrM5;
   g_rules.retestMinBars = InpRetestMinBars;
   g_rules.failedFlipBars = InpFailedFlipBars;
   g_rules.gapBaseBreakout = InpGapBaseBreakout;
   g_rules.expireM15Hours = InpExpireM15Hours;
   g_rules.expireHtfDays = InpExpireHtfDays;
   g_mcfg.timeFilter = InpTimeFilter;
   g_mcfg.vnOffset = InpVnOffset;
   g_mcfg.startMin = InpStartMinVn;
   g_mcfg.endMin = InpEndMinVn;
   g_mcfg.breakCloseMin = InpBreakCloseMin;
   g_mcfg.afterOpenMin = InpAfterOpenMin;
   g_mcfg.maxSpread = InpMaxSpread;
   g_mcfg.newsFilter = InpNewsFilter;
   g_mcfg.newsRequired = false;         // tester: thiếu file lịch tin thì bỏ qua lọc tin, có ghi rõ trong báo cáo
   g_mcfg.specIsSummer = InpSpecSummer;
   g_params = ParamString();
   g_hash = Sha256(g_params);
   g_mode = InpOpenHoldout ? "KIEMTRA" : "KHAMPHA";
   g_folder = "BotVangLab\\" + InpRunName + "_" + g_mode + "_s" + (string)InpSeed + "_" + StringSubstr(g_hash, 0, 8) + "\\";
   if(InpOpenHoldout && !ReadLocks())
      return INIT_FAILED;
   g_half = InpHalfVn - InpVnOffset * 3600;
   g_cut = InpCutVn - InpVnOffset * 3600;
   // ghi thông số ký hiệu
   PrintFormat("[BotVangLab] %s: chữ số %d, point %.5f, bước giá %.5f, contract %.1f, lot nhỏ nhất %.2f, bước lot %.2f, "
               "Stops %d, Freeze %d, kiểu khớp %d, kiểu biểu đồ %d (0 = theo Bid)", _Symbol, _Digits, _Point,
               SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE), SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE),
               SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP),
               (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL), (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL),
               (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_EXEMODE), (int)SymbolInfoInteger(_Symbol, SYMBOL_CHART_MODE));
   for(int d = 0; d <= 6; d++)
     {
      datetime f, to;
      string s = "";
      for(uint i = 0; SymbolInfoSessionTrade(_Symbol, (ENUM_DAY_OF_WEEK)d, i, f, to); i++)
         s += TimeToString(f, TIME_MINUTES) + "–" + TimeToString(to, TIME_MINUTES) + " ";
      PrintFormat("[BotVangLab] phiên giao dịch %s (giờ sàn): %s", d == 0 ? "Chủ nhật" : "thứ " + (string)(d + 1), s == "" ? "không có" : s);
     }
   g_hAtrM5 = iATR(_Symbol, PERIOD_M5, 14);
   if(g_hAtrM5 == INVALID_HANDLE || !g_zones.Init(_Symbol, g_rules))
      return INIT_FAILED;
   g_fakes.Init(g_rules, (ulong)InpSeed, InpFakeMult);
   g_news.Init();
   Print("[BotVangLab] lịch tin: ", g_news.available ? (string)g_news.Count() + " tin mạnh USD" : "KHÔNG CÓ - đã bỏ qua lọc tin");
   long lv = MathMax(SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL), SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL));
   g_sim.Init(SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE), _Digits, lv * _Point);
   ArrayResize(g_spreads, 4096);
   PrintFormat("[BotVangLab] bộ luật %s, mã %s, %s", InpRunName, StringSubstr(g_hash, 0, 8),
               InpOpenHoldout ? "MỞ phần 30% (khóa: " + g_lockedSets + ")" : "khám phá phần 70% (phần 30% đang khóa)");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   g_zones.Release();
   IndicatorRelease(g_hAtrM5);
  }

void OnTick()
  {
   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t))
      return;
   if(!g_ready)
     {
      if(!g_zones.Ready() || BarsCalculated(g_hAtrM5) <= 0)
         return;
      if(!Warmup())
        {
         TesterStop();
         return;
        }
      g_ready = true;
      g_lastTick = t.time;
      g_tick = t;
      return;
     }
   bool gap = t.time - g_lastTick >= 1800;
   g_lastTick = t.time;
   g_tick = t;
   bool newsWin = InpNewsFilter && g_news.available && g_news.InWindow(t.time, InpNewsBefore, InpNewsAfter, InpFomcAfter);
   // 1) lệnh ảo đang chạy
   g_sim.OnTick(t, gap, newsWin, g_atrM5, InpStepAtrMult, InpStepMinSpreadMult);
   if(!g_stopping)
      for(int h = 0; h < g_sim.nHits; h++)
         CreateReverse(g_sim.hits[h], t, newsWin);
   // 2) nến M5 mới: cập nhật vùng, xét sự kiện, vào ảo ở chính tick này
   datetime bar = iTime(_Symbol, PERIOD_M5, 0);
   if(bar != g_lastBar)
     {
      OnNewBar(bar, t, newsWin);
      g_lastBar = bar;
     }
   // 3) chênh lệch của nến đang chạy (để lấy trung vị lúc nến đóng)
   if(g_nSpread >= ArraySize(g_spreads))
      ArrayResize(g_spreads, g_nSpread * 2);
   g_spreads[g_nSpread++] = t.ask - t.bid;
   // 4) phần 30% đang khóa: không ghi sự kiện mới sau mốc, chờ các lệnh ảo xong rồi dừng
   if(!InpOpenHoldout && t.time >= g_cut)
     {
      g_stopping = true;
      if(g_sim.nActive == 0 && !g_stopSent)
        {
         g_stopSent = true;
         TesterStop();
        }
     }
  }

//+------------------------------------------------------------------+
// Tổng kết: ghép cặp, thống kê, HTML, CSV, nhật ký chạy, khóa
double OnTester()
  {
   uint t0 = GetTickCount();
   g_sim.Finish(g_tick);
   double alpha = 0.05;   // mức 95%; số ứng viên đã thử và đã khóa được ghi rõ trong báo cáo
   g_rep.Init(InpCost, alpha, (ulong)InpSeed, InpPairDays);
   g_rep.Compute(g_sim.ev, g_sim.n);
   int explorations = CountExplorations();
   int nReal[3], nFake[3];
   ArrayInitialize(nReal, 0);
   ArrayInitialize(nFake, 0);
   int unfinished = 0;
   for(int i = 0; i < g_sim.n; i++)
     {
      if(g_sim.ev[i].fake)
         nFake[g_sim.ev[i].type]++;
      else
         nReal[g_sim.ev[i].type]++;
      if(g_sim.ev[i].exitReason == EXIT_UNFINISHED)
         unfinished++;
     }
   int partShow = InpOpenHoldout ? 2 : PART_70;
   g_rep.ResetHtml();
   g_rep.H("<!DOCTYPE html><html lang='vi'><head><meta charset='utf-8'><title>BotVangLab " + InpRunName + "</title><style>"
           "body{font-family:Segoe UI,Arial,sans-serif;margin:16px;color:#222}table{border-collapse:collapse;margin:8px 0;font-size:13px}"
           "td,th{border:1px solid #bbb;padding:4px 6px;vertical-align:top}th{background:#eee}small{color:#555}"
           ".ok{color:#0a7a2f;font-weight:bold}.no{color:#b00020;font-weight:bold}</style></head><body>");
   g_rep.H("<h1>BotVangLab: " + InpRunName + " (" + (InpOpenHoldout ? "KIỂM TRA phần 30%" : "KHÁM PHÁ phần 70%") + ")</h1>");
   g_rep.H("<p>Mã bộ tham số: <b>" + StringSubstr(g_hash, 0, 8) + "</b>; hạt giống " + (string)InpSeed + "; chi phí c = "
           + DoubleToString(InpCost, 2) + " giá; mức tin cậy " + DoubleToString(100.0 * (1.0 - alpha), 2) + "%"
           + (InpOpenHoldout ? " (số bộ luật đã khóa: " + (string)g_lockedCount + ")" : "") + ".</p>");
   g_rep.H("<p>Mốc (giờ VN): 70a trước " + TimeToString(InpHalfVn, TIME_DATE) + ", 70b trước " + TimeToString(InpCutVn, TIME_DATE)
           + ", 30 từ " + TimeToString(InpCutVn, TIME_DATE) + ". Đã chạy khám phá " + (string)explorations + " bộ tham số khác nhau; mỗi bộ đo "
           + (string)SET_COUNT + " tập luật. Lịch tin: " + (g_news.available ? (string)g_news.Count() + " tin" : "<b>KHÔNG CÓ – ĐÃ BỎ QUA LỌC TIN</b>")
           + ". Tỉ lệ ATR(H1)/ATR(M5) trung bình: " + (g_ratioN > 0 ? DoubleToString(g_ratioSum / g_ratioN, 2) : "-") + ".</p>");
   g_rep.H("<p>Vùng thật đã tạo: " + (string)g_realZones + "; vùng giả: " + (string)g_fakes.spawned + " (không đặt được " + (string)g_fakes.notPlaced
           + ", bỏ vì giới hạn " + (string)g_fakes.droppedCap + "). Vùng thật bỏ vì giới hạn 60/khung: " + (string)g_zones.droppedCap
           + " (trong đó chưa bị chạm " + (string)g_zones.droppedCapFresh + "), vì quá xa: " + (string)g_zones.droppedFar + ".</p>");
   g_rep.H("<p>Sự kiện thật: vùng lật " + (string)nReal[EV_FLIPPED] + ", vùng chưa lật " + (string)nReal[EV_FRESH] + ", đảo chiều " + (string)nReal[EV_REVERSE]
           + ". Sự kiện giả: " + (string)nFake[EV_FLIPPED] + " / " + (string)nFake[EV_FRESH] + " / " + (string)nFake[EV_REVERSE]
           + " (loại khỏi kho vì trùng nến, cùng chiều với sự kiện thật: " + (string)g_rep.coincident + "; vùng giả đang chồng vùng thật lúc chạm, vẫn giữ: " + (string)g_rep.overlapExcluded + ")"
           + ". Chạm lần đầu không có nến xác nhận (vùng thật): " + (string)g_unconfirmed + ". Không có giá vào trong 30 phút: " + (string)g_noEntry
           + ". Chưa đo xong khi hết dữ liệu: " + (string)unfinished + ". Lỗi lấy dữ liệu: " + (string)g_zones.loadErrors + ".</p>");
   // Kiểm tra cách ghép
   g_rep.H("<h2>1. Kiểm tra cách ghép (giả so với giả, phải gần 0)</h2><table><tr><th>Tập</th><th>Phần</th><th>N</th><th>Chênh p₁</th><th>Khoảng 95%</th><th>Đạt?</th></tr>");
   bool pairOk = true;
   for(int s = 0; s < SET_COUNT; s++)
     {
      int np;
      double d, lo = 0, hi = 0;
      bool ci;
      g_rep.Placebo(s, partShow, g_sim.ev, g_sim.n, np, d, lo, hi, ci);
      // Lệch rõ (khoảng tin cậy không chứa 0) → cách ghép có lỗi; lệch >= 3 điểm mà mẫu nhỏ → chưa đủ dữ liệu để biết
      bool bad = ci && (lo > 0.0 || hi < 0.0);
      bool ok = !bad && MathAbs(d) < 0.03;
      g_rep.placeboBad[s] = bad;
      if(s == 1)
         pairOk = !bad;
      string verdict = ok ? "<span class='ok'>ĐẠT</span>"
                       : (bad ? "<span class='no'>KHÔNG ĐẠT – cách ghép lệch, không dùng so sánh với vùng giả</span>"
                          : "CHƯA ĐỦ DỮ LIỆU (lệch nhưng khoảng tin cậy còn chứa 0)");
      g_rep.H("<tr><td>" + SetName(s) + "</td><td>" + PartName(partShow) + "</td><td>" + (string)np + "</td><td>" + DoubleToString(100.0 * d, 1)
              + " điểm</td><td>" + (ci ? DoubleToString(100.0 * lo, 1) + " … " + DoubleToString(100.0 * hi, 1) : "ít dữ liệu") + "</td><td>"
              + verdict + "</td></tr>");
     }
   g_rep.H("</table>");
   // Kết quả chính
   g_rep.H("<h2>2. Kết quả theo tập luật</h2><p><small>p_k: tỉ lệ đi +kB trước khi lỗ 1B (hết 36 nến = không đạt), khoảng Wilson và mức hòa vốn ở c."
           + " Thật − giả: trên sự kiện có đối chứng, khoảng bootstrap theo ngày. R: kết quả mỗi lệnh theo cách chạy của bot, đơn vị B, sau chi phí c.</small></p>");
   g_rep.H("<table><tr><th>Tập luật</th><th>Phần</th><th>N</th><th>Có đối chứng</th><th>Ngày</th><th>p₁</th><th>p₂</th><th>p₃</th><th>p₁ giả</th>"
           "<th>Thật − giả (p₁)</th><th>R mọi sự kiện</th><th>R có đối chứng</th><th>R giả</th><th>R ở c = 0/0,1/0,2/0,3/0,5</th><th>Ghi chú</th></tr>");
   for(int s = 0; s < SET_COUNT; s++)
     {
      g_rep.H(g_rep.ResultRow(s, 0));
      g_rep.H(g_rep.ResultRow(s, 1));
      g_rep.H(g_rep.ResultRow(s, PART_70));
      if(InpOpenHoldout)
         g_rep.H(g_rep.ResultRow(s, 2));
     }
   g_rep.H("</table>");
   // Kết luận
   g_rep.H("<h2>3. Kết luận</h2>" + (pairOk ? "" : "<p class='no'>Cách ghép chưa đạt: các so sánh với vùng giả chưa đáng tin.</p>")
           + "<table><tr><th>Tập luật</th><th>Mã</th><th>Kết luận</th></tr>");
   for(int s = 0; s < SET_COUNT; s++)
     {
      if(s == 2)
         continue;
      bool locked = StringFind("," + g_lockedSets, "," + SetCode(s) + ",") >= 0;
      g_rep.H("<tr><td>" + SetName(s) + "</td><td>" + SetCode(s) + "</td><td>" + g_rep.Verdict(s, InpOpenHoldout, locked) + "</td></tr>");
     }
   g_rep.H("</table>");
   g_rep.H("<h2>4. Bảng cân bằng</h2>");
   g_rep.Balance(1, partShow, g_sim.ev, g_sim.n);
   g_rep.Balance(0, partShow, g_sim.ev, g_sim.n);
   g_rep.H("<h2>5. Theo nhóm</h2>");
   g_rep.Groups(1, partShow, g_sim.ev, g_sim.n);
   g_rep.Groups(0, partShow, g_sim.ev, g_sim.n);
   g_rep.H("<h2>6. Chuỗi lệnh của bot</h2>");
   g_rep.BotSequence(partShow, g_sim.ev, g_sim.n);
   g_rep.H("<p><small>Tính trong " + (string)(GetTickCount() - t0) + " ms. Tham số: " + g_params + "</small></p></body></html>");
   // Ghi file
   bool okCsv = g_rep.WriteEvents(g_folder, g_sim.ev, g_sim.n, _Digits);
   int h = FileOpen(g_folder + "tong_ket.html", FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON, 0, CP_UTF8);
   if(h != INVALID_HANDLE)
     {
      FileWriteString(h, g_rep.Html());
      FileClose(h);
     }
   AppendLine("BotVangLab\\nhat_ky_chay.csv", InpRunName + ";" + g_hash + ";" + g_mode + ";" + (string)InpSeed + ";"
              + (string)nReal[EV_FLIPPED] + ";" + (string)nFake[EV_FLIPPED]);
   if(InpOpenHoldout)
      AppendLine("BotVangLab\\nhat_ky_mo_30.csv", InpRunName + ";" + g_hash + ";" + g_lockedSets + ";" + (string)g_lockedCount);
   if(InpWriteLock && !InpOpenHoldout)
     {
      string codes[];
      int nc = StringSplit(InpLockSets, ',', codes);
      for(int c = 0; c < nc; c++)
        {
         int s = -1;
         for(int k = 0; k < SET_COUNT; k++)
            if(SetCode(k) == codes[c])
               s = k;
         if(s < 0)
           {
            Print("[BotVangLab] mã tập luật không có: ", codes[c]);
            continue;
           }
         AppendLine("BotVangLab\\khoa_ung_vien.csv", InpRunName + ";" + g_hash + ";" + codes[c] + ";"
                    + (g_rep.Crit3(s) && !g_rep.placeboBad[s] ? "qua_tc3" : "KHONG_qua_tc3") + ";" + g_params);
         Print("[BotVangLab] đã khóa ", codes[c], " của bộ ", StringSubstr(g_hash, 0, 8));
        }
     }
   // Tóm tắt vào nhật ký tester
   PrintFormat("[BotVangLab] xong trong %u ms; file: Common\\Files\\%s (csv %s)", GetTickCount() - t0, g_folder, okCsv ? "ok" : "LỖI");
   for(int s = 0; s < SET_COUNT; s++)
     {
      SetResult r = g_rep.res[s][partShow];
      PrintFormat("[BotVangLab] %-12s phần %s: N=%d đối chứng=%d p1=%.3f giả=%.3f thật-giả=%+.3f [%s] R=%.3f R(đối chứng)=%.3f [%s] %s",
                  SetCode(s), PartName(partShow), r.nReal, r.nPaired, r.nReal > 0 ? (double)r.win[0] / r.nReal : 0.0, r.fakeP1, r.d1,
                  r.d1ci ? DoubleToString(r.d1lo, 3) + ";" + DoubleToString(r.d1hi, 3) : "-", r.rAll, r.rPair,
                  r.rci ? DoubleToString(r.rlo, 3) + ";" + DoubleToString(r.rhi, 3) : "-", g_rep.Crit3(s) ? "TC3 qua" : "TC3 không");
     }
   SetResult base = g_rep.res[1][partShow];
   return base.d1ci ? base.d1lo : base.d1;
  }
