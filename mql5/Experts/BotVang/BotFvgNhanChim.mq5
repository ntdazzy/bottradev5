// BotFvgNhanChim: bot demo cho đúng một luật đã đo bằng PhanUngLab (SPEC §23): vàng XAUUSDm khung M5, vùng FVG + nến nhấn chìm
// ở lần chạm đầu, theo tín hiệu, chốt lời 2R, 0,01 lot, nhiều lệnh cùng lúc (chặn lỗi ở 20 lệnh), giữ tối đa 500 nến.
// Giữ giới hạn lỗ ngày/tuần/tổng (§11.2) và kiểm tra ký quỹ (§11.4); không có luật rủi ro 0,5% (§11.1), không lọc giờ/tin/chênh
// lệch (§12.1). Luật đóng băng. Mặc định TẮT; chỉ chạy trên tài khoản demo. Vùng và tín hiệu dùng chung code với PhanUngLab.
#property copyright "BotVang"
#property version   "1.00"
#property description "Bot demo FVG + nến nhấn chìm, vàng M5, chốt lời 2R (SPEC §23). Mặc định TẮT, chỉ chạy trên tài khoản demo."

#include <BotVang/SmcDetect.mqh>
#include <BotVang/SmcZones.mqh>
#include <BotVang/Stats.mqh>
#include <BotVang/Filters.mqh>
#include <BotVang/Exec.mqh>
#include <BotVang/FvgNcBook.mqh>
#include <BotVang/FvgNcJournal.mqh>

input bool     InpEnabled = false;            // Bật bot: được mở lệnh mới (mặc định TẮT; chỉ bật trên tài khoản demo)
input long     InpMagic = 20260930;           // Mã nhận diện lệnh của bot (Magic)
input int      InpVnOffset = 7;               // Giờ VN = giờ sàn + số giờ này
input double   InpDayLoss = 10.0;             // Giới hạn lỗ ngày (% Equity đầu ngày VN): đóng hết, nghỉ tới 00:00 VN hôm sau
input double   InpWeekLoss = 20.0;            // Giới hạn lỗ tuần (% Equity 00:00 VN thứ Hai): đóng hết, nghỉ tới tuần sau
input double   InpTotalLoss = 15.0;           // Giới hạn lỗ tổng (% vốn gốc): đóng hết, dừng hẳn
input double   InpMinFreeMarginPct = 50.0;    // Ký quỹ trống sau lệnh >= % Equity
input double   InpMinMarginLevel = 500.0;     // Mức ký quỹ sau lệnh >= %

// Luật đóng băng (SPEC §23.1), không phải cài đặt
#define BOT_NAME    "BotFvgNhanChim"
#define BOT_SYMBOL  "XAUUSDm"
#define BOT_LOT     0.01
#define TP_R        2.0
#define MAX_HOLD    500               // giữ tối đa: số nến M5 đã đóng tính từ nến có giờ mở lệnh
#define MAX_POS     20                // chặn lỗi: số lệnh của bot đang mở
#define WARM_FROM   D'2026.01.05'     // nạp lại nến M5 từ lúc PhanUngLab bắt đầu đo ...
#define WARM_BARS   1000              // ... hoặc từ 1000 nến trước (như PhanUngLab), lấy mốc sớm hơn
#define TAG         "FvgNC"           // ghi chú lệnh: "FvgNC yyyy.mm.dd hh:mi" (giờ mở nến tín hiệu, giờ sàn)
#define SK_LAST_BAR "lastBar"         // State: giờ mở nến M5 đã đóng cuối cùng đã xử lý
#define CLOSE_RETRY 10                // lệnh bot đã gửi đóng mà vẫn còn: gửi lại sau số giây này

// Lý do bỏ tín hiệu
#define SKIP_OFF     0
#define SKIP_LIMIT   1
#define SKIP_SL_HIT  2
#define SKIP_STOPS   3
#define SKIP_MAXPOS  4
#define SKIP_CLOSED  5
#define SKIP_MARGIN  6
#define SKIP_BUSY    7
#define SKIP_SEND    8
#define SKIP_COUNT   9
string SkipName[SKIP_COUNT] = {"bot TẮT", "giới hạn lỗ", "dừng lỗ đã bị vượt lúc vào", "dừng lỗ/chốt lời gần hơn mức tối thiểu của sàn",
                               "đủ 20 lệnh", "sàn đóng / không cho giao dịch", "ký quỹ", "lệnh trước đang chờ gửi lại", "sàn từ chối"};

CSmcBars       g_bars;
CSmcStructure  g_big;              // cấu trúc lớp lớn (pivot 20/20): đáy/đỉnh cho dừng lỗ
CSmcFvgs       g_fvg;
CSmcZones      g_zones;
CState         g_st;
CMoney         g_money;
BotSettings    g_set;
CJournal       g_log;
CExec          g_ex;
CFvgBook       g_book;
CFvgJournal    g_jr;
bool           g_tester = false;
bool           g_ready = false;
string         g_fatal = "";       // lý do không chạy (sai ký hiệu/khung, tài khoản không phải hedging/demo, lot)
string         g_warn = "";
datetime       g_curBar = 0;       // giờ mở nến M5 đang chạy
datetime       g_lastBar = 0;      // giờ mở nến M5 đã đóng cuối cùng đã xử lý
datetime       g_prevLast = 0;     // nến cuối đã xử lý ở lần chạy trước (State): không bao giờ vào lệnh lại ở nến này hoặc trước
bool           g_hard = false;     // dừng hẳn (giới hạn lỗ tổng)
datetime       g_pauseUntil = 0;   // nghỉ tới (giới hạn lỗ ngày/tuần)
int            g_pauseWhy = 0;     // 1 ngày, 2 tuần
datetime       g_lastSec = 0;      // giây của tick đã kiểm tra tiền gần nhất
datetime       g_lastSync = 0;
bool           g_needSync = true;
int            g_touchDay = 0;
string         g_lastSig = "chưa có";
int            g_signals = 0, g_sent = 0, g_conflicts = 0, g_missed = 0, g_maxOpen = 0;
int            g_skip[SKIP_COUNT];

string Vn(datetime server) { return TimeToString(server + InpVnOffset * 3600, TIME_DATE | TIME_MINUTES) + " VN"; }
string Px(double p) { return DoubleToString(p, _Digits); }
string Money(double v) { return (v >= 0 ? "+" : "") + DoubleToString(v, 2); }

// Không chạy: ghi lý do vào log, lên chart, và báo (chạy thật)
void Refuse(const string why)
  {
   g_fatal = why;
   g_log.Add("khong_chay", why);
   Comment(BOT_NAME + ": KHÔNG CHẠY — " + why);
   if(!g_tester)
      Alert(BOT_NAME + ": không chạy — " + why);
  }

bool Stop(const string why)
  {
   Refuse(why);
   ExpertRemove();
   return false;
  }

// SL (SPEC §22.3, như PhanUngLab): mua = đáy lớn gần nhất có giá ≤ mốc, trừ 0,1 ATR; không có thì mốc − 0,1 ATR. Bán ngược lại.
double WideSl(int dir, double base, double atr)
  {
   double p = dir > 0 ? g_big.NearestLow(base) : g_big.NearestHigh(base);
   return (p != 0.0 ? p : base) - dir * 0.1 * atr;
  }

// Dừng lỗ đã chạm ở tick t theo đúng phía (mua khi Bid ≤ SL, bán khi Ask ≥ SL)
bool StopHit(int dir, double sl, const MqlTick &t) { return dir > 0 ? t.bid <= sl : t.ask >= sl; }

// Chỉ số nến M5 đầu tiên có giờ mở ≥ t (g_bars.n nếu không có)
int BarIndexAt(datetime t)
  {
   int lo = 0, hi = g_bars.n;
   while(lo < hi)
     {
      int mid = (lo + hi) / 2;
      if(g_bars.b[mid].t < t)
         lo = mid + 1;
      else
         hi = mid;
     }
   return lo;
  }

// Vùng FVG vừa có phản ứng nhấn chìm ở nến i theo chiều dir: trả về số vùng, top/bottom của vùng xuất hiện sau cùng
int FiredZones(int dir, int i, double &top, double &bottom)
  {
   int cnt = 0;
   for(int k = 0; k < g_zones.n; k++)
     {
      SmcZone z = g_zones.z[k];
      if(z.type != ZT_FVG || z.dir != dir || (z.k0 != i && z.k0 != i - 1) || (z.fired & (1 << ZR_R2)) == 0
         || !IsR2(z, g_bars.b[i - 1], g_bars.b[i]))
         continue;
      top = z.top;
      bottom = z.bottom;
      cnt++;
     }
   return cnt;
  }

// Thêm một nến M5 đã đóng vào vùng/cấu trúc (như PhanUngLab). Trả về mặt nạ chiều ZS_* của tín hiệu FVG + nhấn chìm ở nến này.
int ProcessBar(const MqlRates &r)
  {
   int i = g_bars.Add(r);
   g_fvg.OnBar(g_bars, i);
   SmcBreak ev0, ev1;
   ZeroMemory(ev0);   // cấu trúc nội bộ chỉ sinh vùng OB, luật này không dùng
   g_big.OnBar(g_bars, i, ev1);
   g_zones.OnBar(g_bars, i, ev0, ev1, g_fvg);
   return i >= 1 && g_bars.Ready() ? g_zones.react[ZT_FVG * 3 + ZR_R2] : 0;
  }

// Nạp lại nến M5 đã đóng (không vào lệnh) để vùng và đỉnh/đáy giống lúc chạy liên tục như PhanUngLab. False: lịch sử chưa sẵn sàng.
bool Warmup(void)
  {
   if(!g_tester && !SeriesInfoInteger(_Symbol, _Period, SERIES_SYNCHRONIZED))
      return false;
   datetime cur = iTime(_Symbol, _Period, 0), last = iTime(_Symbol, _Period, 1);
   if(cur == 0 || last == 0)
      return false;
   datetime from = WARM_FROM, b = iTime(_Symbol, _Period, WARM_BARS);
   if(b > 0 && b < from)
      from = b;
   MqlRates h[];
   ArraySetAsSeries(h, false);
   int got = CopyRates(_Symbol, _Period, from, last, h);
   if(got <= 0 || h[got - 1].time != last)
      return false;
   for(int k = 0; k < got; k++)
      if(ProcessBar(h[k]) != 0 && g_prevLast > 0 && h[k].time > g_prevLast)
         g_missed++;   // tín hiệu ở nến đóng lúc bot không chạy: không vào lại (đã qua tick đầu sau nến)
   g_curBar = cur;
   g_lastBar = last;
   g_st.Set(SK_LAST_BAR, (double)last);
   if(h[0].time - from > 3 * 86400)
      g_warn = "lịch sử nến M5 trên máy chỉ có từ " + Vn(h[0].time) + " (cần từ " + Vn(from) + "): dừng lỗ có thể khác lúc đo";
   g_log.Add("nap_lich_su", StringFormat("Nạp %d nến M5 từ %s tới %s%s", got, Vn(h[0].time), Vn(last),
                                         g_missed > 0 ? StringFormat("; %d tín hiệu ở nến đóng lúc bot không chạy: không vào lại", g_missed) : ""));
   return true;
  }

// Lần đầu có tick khi đã kết nối sàn: kiểm tra tài khoản, nạp lịch sử, đọc trạng thái đã lưu, nhận lại lệnh đang mở
bool Ready(void)
  {
   if(AccountInfoDouble(ACCOUNT_EQUITY) <= 0.0 || (!g_tester && !TerminalInfoInteger(TERMINAL_CONNECTED)))
      return false;
   if(AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      return Stop("tài khoản không phải kiểu hedging: bot cần giữ nhiều lệnh cùng lúc");
   if(!g_tester && AccountInfoInteger(ACCOUNT_TRADE_MODE) != ACCOUNT_TRADE_MODE_DEMO)
      return Stop("bot demo (SPEC §23): chỉ chạy trên tài khoản demo");
   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), vmax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double vstep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(vstep <= 0.0)
      return false;   // thông số ký hiệu chưa về
   if(BOT_LOT < vmin - 1e-9 || BOT_LOT > vmax + 1e-9 || MathAbs(BOT_LOT / vstep - MathRound(BOT_LOT / vstep)) > 1e-6)
      return Stop(StringFormat("sàn không cho lot %.2f (nhỏ nhất %.2f, lớn nhất %.2f, bước %.2f)", BOT_LOT, vmin, vmax, vstep));
   if(!g_st.Init(_Symbol, InpMagic))
      return Stop("tên khóa lưu trạng thái quá dài");
   if(g_tester)
      GlobalVariablesDeleteAll(g_st.Prefix());   // mỗi lần chạy tester bắt đầu từ trạng thái trống
   g_prevLast = (datetime)g_st.Get(SK_LAST_BAR, 0);
   if(!Warmup())
      return false;   // thử lại ở tick sau
   string why;
   g_ex.Init(_Symbol, InpMagic, GetPointer(g_log), why);
   g_money.Init(_Symbol, InpMagic, InpVnOffset, GetPointer(g_st));
   g_hard = g_st.Get(SK_HARD, 0) > 0.0;
   g_pauseUntil = (datetime)g_st.Get(SK_PAUSE, 0);
   g_pauseWhy = (int)g_st.Get(SK_PAUSE_WHY, 0);
   // Cho chạy lại sau khi dừng hẳn (§11.2 "chỉ khi chủ bot bấm"): chủ bot đặt InpEnabled = false rồi bật lại true. Vốn gốc tính lại.
   if(g_hard && InpEnabled && g_st.Get(SK_BOT_ON, 0) == 0.0)
     {
      g_hard = false;
      g_st.Set(SK_HARD, 0);
      g_st.Set(SK_CAPITAL, AccountInfoDouble(ACCOUNT_EQUITY));
      g_st.Set(SK_CAP_TIME, (double)TimeCurrent());
      g_log.Add("chay_lai", "Bạn cho chạy lại sau khi dừng hẳn; vốn gốc tính lại từ bây giờ: " + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2));
     }
   g_st.Set(SK_BOT_ON, InpEnabled ? 1 : 0);
   g_book.Init(GetPointer(g_st), _Symbol, InpMagic, TAG);
   g_book.Load();
   string file = BOT_NAME + "\\" + (g_tester ? "tester_" + _Symbol : "lenh_" + (string)AccountInfoInteger(ACCOUNT_LOGIN) + "_" + _Symbol) + ".csv";
   g_jr.Init(file, g_tester, _Digits);
   g_ready = true;
   SyncBook();
   CheckMoney(TimeCurrent());
   g_log.Add("khoi_dong", StringFormat("%s trên %s M5, Magic %I64d, bot %s; đang mở %d lệnh của bot; nhật ký lệnh: Common\\Files\\%s%s",
                                       BOT_NAME, _Symbol, InpMagic, InpEnabled ? "BẬT" : "TẮT", g_book.n, file,
                                       g_hard ? "; ĐANG DỪNG HẲN" : ""));
   return true;
  }

bool Blocked(datetime now) { return g_hard || now < g_pauseUntil; }

// Giới hạn lỗ §11.2 (gồm lệnh đang mở): tổng → dừng hẳn; ngày/tuần → nghỉ. Đang bị chặn thì đóng mọi lệnh của bot.
void CheckMoney(datetime now)
  {
   g_money.Update(now);
   int hit = g_money.LimitHit(g_set);
   if(hit == 3 && !g_hard)
     {
      g_hard = true;
      g_st.Set(SK_HARD, 1);
      g_log.Add("dung_han", StringFormat("Lỗ tổng %s chạm giới hạn %.0f%% vốn gốc %.2f: đóng hết lệnh của bot, dừng hẳn. Muốn chạy lại: tắt bot rồi bật lại",
                                         Money(g_money.totalPnl), InpTotalLoss, g_money.capital));
     }
   else
      if((hit == 1 || hit == 2) && now >= g_pauseUntil)
        {
         g_pauseUntil = hit == 1 ? VnDayStart(now, InpVnOffset) + 86400 : VnWeekStart(now, InpVnOffset) + 7 * 86400;
         g_pauseWhy = hit;
         g_st.Set(SK_PAUSE, (double)g_pauseUntil);
         g_st.Set(SK_PAUSE_WHY, hit);
         g_log.Add("nghi", StringFormat("Chạm giới hạn lỗ %s (%s): đóng hết lệnh của bot, nghỉ tới %s", hit == 1 ? "ngày" : "tuần",
                                        Money(hit == 1 ? g_money.dayPnl : g_money.weekPnl), Vn(g_pauseUntil)));
        }
   if(Blocked(now))
      for(int k = 0; k < g_book.n; k++)
         if(g_book.t[k].closeWhy == 0)
            g_book.RequestClose(k, FX_LIMIT);
  }

// Đối chiếu sổ lệnh với sàn: ghi lệnh mới thấy vào log, ghi lệnh đã đóng vào nhật ký
void SyncBook(void)
  {
   FvgTrade opened[], closed[];
   FvgExit exits[];
   int nc = g_book.Sync(opened, closed, exits);
   for(int k = 0; k < ArraySize(opened); k++)
     {
      FvgTrade x = opened[k];
      if(x.want > 0.0)
         g_log.Add("vao_lenh", StringFormat("#%I64d %s %.2f lot khớp %s (giá lúc gửi %s), SL %s, TP %s", x.id, x.dir > 0 ? "MUA" : "BÁN", x.vol,
                                            Px(x.fill), Px(x.want), Px(x.sl), Px(x.tp)));
      else
         g_log.Add("nhan_lai", StringFormat("Nhận lại lệnh #%I64d %s của bot (không có thông tin tín hiệu), khớp %s, SL %s, TP %s", x.id,
                                            x.dir > 0 ? "MUA" : "BÁN", Px(x.fill), Px(x.sl), Px(x.tp)));
     }
   for(int k = 0; k < nc; k++)
     {
      g_jr.Trade(closed[k], exits[k]);
      g_log.Add("dong_lenh", StringFormat("#%I64d %s: %s ở %s, %s %s", closed[k].id, closed[k].dir > 0 ? "MUA" : "BÁN",
                                          exits[k].known ? CFvgJournal::ReasonText(exits[k].reason) : "không đọc được lịch sử",
                                          Px(exits[k].price), Money(exits[k].money), AccountInfoString(ACCOUNT_CURRENCY)));
     }
   g_needSync = false;
   g_lastSync = TimeCurrent();
   g_maxOpen = MathMax(g_maxOpen, g_book.n);
   if(g_book.HasWant() && TimeCurrent() - g_book.WantAt() > 60 && !g_ex.Busy(RQ_OPEN))
     {
      g_book.CancelWant();
      g_log.Add("khong_thay_lenh", "Lệnh vừa gửi không thấy trên sàn sau 60 giây: bỏ");
     }
  }

// Gửi (hoặc gửi lại sau CLOSE_RETRY giây) lệnh đóng cho các lệnh bot đang đóng (giữ đủ 500 nến, giới hạn lỗ)
void ProcessCloses(datetime now)
  {
   for(int k = 0; k < g_book.n; k++)
     {
      FvgTrade x = g_book.t[k];
      if(x.closeWhy == 0 || x.ticket == 0 || (x.closeSent > 0 && now - x.closeSent < CLOSE_RETRY) || g_ex.Busy(RQ_CLOSE)
         || !PositionSelectByTicket(x.ticket))
         continue;
      g_book.t[k].closeSent = now;
      g_log.Add("gui_dong", StringFormat("Đóng lệnh #%I64d %s: %s", x.id, x.dir > 0 ? "MUA" : "BÁN", CFvgJournal::ReasonText(x.closeWhy)));
      g_ex.Close(x.ticket, x.dir, PositionGetDouble(POSITION_VOLUME));
      g_needSync = true;
     }
  }

// Lệnh giữ đủ MAX_HOLD nến M5 (tính cả nến có giờ mở lệnh) tới nến i vừa đóng: đóng theo giá thị trường (như PhanUngLab)
void CloseExpired(int i)
  {
   int ps = PeriodSeconds(_Period);
   for(int k = 0; k < g_book.n; k++)
     {
      FvgTrade x = g_book.t[k];
      if(x.closeWhy != 0 || x.fillTime == 0)
         continue;
      int first = BarIndexAt(x.fillTime - x.fillTime % ps);
      if(first <= i && i - first + 1 >= MAX_HOLD)
         g_book.RequestClose(k, FX_TIME);
     }
  }

// Sàn có cho mở lệnh chiều dir lúc now không (nút giao dịch tự động, tài khoản, chế độ ký hiệu, phiên giao dịch)
bool TradeAllowed(int dir, datetime now, string &why)
  {
   if(!g_tester && !TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
     {
      why = "nút Algo Trading của MT5 đang tắt";
      return false;
     }
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED) || !AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) || !AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
     {
      why = "bot hoặc tài khoản không được phép giao dịch tự động";
      return false;
     }
   long mode = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   if(mode != SYMBOL_TRADE_MODE_FULL && !(mode == SYMBOL_TRADE_MODE_LONGONLY && dir > 0) && !(mode == SYMBOL_TRADE_MODE_SHORTONLY && dir < 0))
     {
      why = "sàn không cho mở lệnh chiều này (chế độ giao dịch " + (string)mode + ")";
      return false;
     }
   int toEnd, fromStart;
   if(!SessionInfo(_Symbol, now, toEnd, fromStart))
     {
      why = "sàn đang đóng (ngoài phiên giao dịch)";
      return false;
     }
   return true;
  }

void Note(const string text)
  {
   g_lastSig = text;
   g_log.Add("tin_hieu", text);
  }

// Tín hiệu ở nến i vừa đóng (SPEC §23.1): vào lệnh thị trường ở tick t (tick đầu bot thấy sau nến nhấn chìm)
void OnSignal(int mask, int i, const MqlTick &t)
  {
   g_signals++;
   datetime sig = g_bars.b[i].t;
   if(mask == (ZS_BUY | ZS_SELL))
     {
      g_conflicts++;
      Note("nến " + Vn(sig) + ": có cả tín hiệu mua lẫn bán cùng nến → bỏ cả hai (§22.5)");
      return;
     }
   int dir = mask == ZS_BUY ? 1 : -1;
   SmcBar b = g_bars.b[i], a = g_bars.b[i - 1];
   double base = dir > 0 ? MathMin(b.l, a.l) : MathMax(b.h, a.h);   // cực trị của 2 nến nhấn chìm
   double atr = b.atr;
   double sl = WideSl(dir, base, atr);
   double entry = dir > 0 ? t.ask : t.bid;
   double risk = (entry - sl) * dir;
   double tp = entry + dir * TP_R * risk;
   double zTop = 0.0, zBot = 0.0;
   int zones = FiredZones(dir, i, zTop, zBot);
   string head = StringFormat("nến %s %s, vùng FVG %s–%s%s, giá %s, SL %s, TP %s", Vn(sig), dir > 0 ? "MUA" : "BÁN", Px(zBot), Px(zTop),
                              zones > 1 ? StringFormat(" (+%d vùng)", zones - 1) : "", Px(entry), Px(sl), Px(tp));
   double slN = g_ex.Norm(sl), tpN = g_ex.Norm(tp);
   double dSl = dir > 0 ? t.bid - slN : slN - t.ask, dTp = dir > 0 ? tpN - t.bid : t.ask - tpN;
   string why = "";
   int skip = -1;
   if(!InpEnabled)
     {
      skip = SKIP_OFF;
      why = "bot đang TẮT";
     }
   else
      if(Blocked(t.time))
        {
         skip = SKIP_LIMIT;
         why = g_hard ? "đang dừng hẳn (giới hạn lỗ tổng)" : "đang nghỉ vì giới hạn lỗ tới " + Vn(g_pauseUntil);
        }
      else
         if(StopHit(dir, sl, t) || atr <= 0.0)
           {
            skip = SKIP_SL_HIT;
            why = "dừng lỗ đã bị vượt ngay lúc vào";
           }
         else
            if(dSl <= 0.0 || dTp <= 0.0 || dSl < g_ex.minDist || dTp < g_ex.minDist)
              {
               skip = SKIP_STOPS;
               why = "dừng lỗ/chốt lời gần hơn mức tối thiểu của sàn";
              }
            else
               if(g_book.n + (g_book.HasWant() ? 1 : 0) >= MAX_POS)
                 {
                  skip = SKIP_MAXPOS;
                  why = StringFormat("đã có %d lệnh của bot đang mở (chặn lỗi)", MAX_POS);
                 }
               else
                  if(!TradeAllowed(dir, t.time, why))
                     skip = SKIP_CLOSED;
                  else
                     if(!g_money.MarginOk(dir, BOT_LOT, entry, g_set, why))
                        skip = SKIP_MARGIN;
                     else
                        if(g_ex.Busy(RQ_OPEN) || g_ex.CoolingDown())
                          {
                           skip = SKIP_BUSY;
                           why = "lệnh trước đang chờ gửi lại";
                          }
   if(skip >= 0)
     {
      g_skip[skip]++;
      Note(head + " → bỏ: " + why);
      return;
     }
   FvgTrade x;
   ZeroMemory(x);
   x.sig = sig;
   x.dir = dir;
   x.zTop = zTop;
   x.zBot = zBot;
   x.zones = zones;
   x.want = entry;
   x.sl = slN;
   x.tp = tpN;
   string tag = TAG + " " + TimeToString(sig, TIME_DATE | TIME_MINUTES);
   g_book.Expect(x, tag);
   if(g_ex.Open(dir, BOT_LOT, sl, tag, tp))
     {
      g_sent++;
      Note(head + " → đã vào lệnh");
      SyncBook();
      return;
     }
   if(g_ex.Busy(RQ_OPEN))
     {
      g_sent++;
      Note(head + " → sàn chưa nhận, đang thử lại");
      return;
     }
   g_book.CancelWant();
   g_skip[SKIP_SEND]++;
   Note(head + " → bỏ: sàn từ chối (" + g_log.Recent(0) + ")");
  }

// Nến M5 mới: xử lý các nến vừa đóng (thường 1 nến; mất kết nối thì nhiều nến, chỉ nến cuối được vào lệnh), đóng lệnh giữ quá lâu,
// rồi xét tín hiệu ở nến cuối (như PhanUngLab: đóng lệnh quá hạn trước, vào lệnh mới sau)
void NewBar(const MqlTick &t)
  {
   datetime cur = iTime(_Symbol, _Period, 0);
   if(cur == 0 || cur == g_curBar)
      return;
   MqlRates r[];
   ArraySetAsSeries(r, false);
   int got = CopyRates(_Symbol, _Period, g_lastBar + 1, cur - 1, r);
   if(got < 0)
      return;   // chưa lấy được nến vừa đóng: thử lại ở tick sau
   g_curBar = cur;
   if(got == 0)
      return;
   int mask = 0;
   for(int k = 0; k < got; k++)
     {
      mask = ProcessBar(r[k]);
      if(mask != 0 && k < got - 1)
         g_missed++;   // nến đã đóng mà bot không thấy tick đầu sau nó: không vào lệnh
     }
   g_lastBar = r[got - 1].time;
   g_st.Set(SK_LAST_BAR, (double)g_lastBar);
   CheckMoney(t.time);
   SyncBook();
   CloseExpired(g_bars.n - 1);
   ProcessCloses(t.time);
   if(mask != 0 && g_lastBar > g_prevLast)
      OnSignal(mask, g_bars.n - 1, t);
  }

string StatusText(void)
  {
   if(g_fatal != "")
      return BOT_NAME + ": KHÔNG CHẠY — " + g_fatal;
   if(!g_ready)
      return BOT_NAME + ": đang chờ kết nối sàn và nạp lịch sử nến M5...";
   datetime now = TimeCurrent();
   string state = InpEnabled ? "đang chạy, chờ tín hiệu" : "TẮT: không mở lệnh mới (lệnh đang mở vẫn được quản lý)";
   if(g_hard)
      state = StringFormat("DỪNG HẲN vì lỗ tổng chạm %.0f%%. Muốn chạy lại: đặt InpEnabled = false, rồi bật lại true", InpTotalLoss);
   else
      if(now < g_pauseUntil)
         state = "NGHỈ tới " + Vn(g_pauseUntil) + " vì chạm giới hạn lỗ " + (g_pauseWhy == 1 ? "ngày" : "tuần");
   int buys = 0, sells = 0;
   double open = 0.0;
   for(int k = 0; k < g_book.n; k++)
     {
      if(g_book.t[k].dir > 0)
         buys++;
      else
         sells++;
      if(g_book.t[k].ticket != 0 && PositionSelectByTicket(g_book.t[k].ticket))
         open += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
     }
   string cur = AccountInfoString(ACCOUNT_CURRENCY);
   string s = StringFormat("%s (SPEC §23, demo) — %s M5 — %s\n", BOT_NAME, _Symbol, InpEnabled ? "BẬT" : "TẮT");
   s += "Trạng thái: " + state + "\n";
   s += StringFormat("Lệnh đang mở: %d/%d (mua %d, bán %d), lời/lỗ đang mở %s %s\n", g_book.n, MAX_POS, buys, sells, Money(open), cur);
   s += StringFormat("Lời/lỗ hôm nay %s (giới hạn -%.2f) · tuần %s (-%.2f) · tổng %s (-%.2f) %s\n", Money(g_money.dayPnl), g_money.DayLimit(g_set),
                     Money(g_money.weekPnl), g_money.WeekLimit(g_set), Money(g_money.totalPnl), g_money.TotalLimit(g_set), cur);
   s += "Tín hiệu cuối: " + g_lastSig;
   if(g_warn != "")
      s += "\nLưu ý: " + g_warn;
   return s;
  }

void Summary(void)
  {
   string s = StringFormat("%d nến có tín hiệu, bỏ %d nến có cả mua lẫn bán, gửi %d lệnh, nhật ký %d dòng, nhiều nhất %d lệnh cùng lúc, "
                           "bỏ lỡ %d tín hiệu lúc bot không chạy", g_signals, g_conflicts, g_sent, g_jr.rows, g_maxOpen, g_missed);
   for(int k = 0; k < SKIP_COUNT; k++)
      if(g_skip[k] > 0)
         s += StringFormat("; bỏ vì %s: %d", SkipName[k], g_skip[k]);
   g_log.Add("tong_ket", s);
  }

int OnInit()
  {
   // đổi tham số/khung: EA không nạp lại từ đầu nên phải xóa hết trạng thái cũ
   g_tester = MQLInfoInteger(MQL_TESTER) != 0;
   g_ready = false;
   g_fatal = "";
   g_warn = "";
   g_curBar = 0;
   g_lastBar = 0;
   g_prevLast = 0;
   g_lastSec = 0;
   g_lastSync = 0;
   g_needSync = true;
   g_touchDay = 0;
   g_lastSig = "chưa có";
   g_signals = 0;
   g_sent = 0;
   g_conflicts = 0;
   g_missed = 0;
   g_maxOpen = 0;
   ArrayInitialize(g_skip, 0);
   g_bars.Init();
   g_big.Init(20);
   g_fvg.Init();
   g_zones.Init();
   g_log.Init(false, InpVnOffset, BOT_NAME);
   if(_Symbol != BOT_SYMBOL || _Period != PERIOD_M5)
     {
      Refuse(StringFormat("chỉ chạy trên %s khung M5 (đang gắn vào %s %s)", BOT_SYMBOL, _Symbol, StringSubstr(EnumToString(_Period), 7)));
      return INIT_FAILED;
     }
   ZeroMemory(g_set);
   g_set.magic = InpMagic;
   g_set.lot = BOT_LOT;
   g_set.limitUnit = LIMIT_PERCENT;
   g_set.dayLoss = InpDayLoss;
   g_set.weekLoss = InpWeekLoss;
   g_set.totalLoss = InpTotalLoss;
   g_set.profitTargetOn = false;
   g_set.minFreeMarginPct = InpMinFreeMarginPct;
   g_set.minMarginLevel = InpMinMarginLevel;
   if(!g_tester || MQLInfoInteger(MQL_VISUAL_MODE))
      EventSetTimer(1);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   if(!g_ready)
      return;
   g_jr.Flush();
   if(!g_tester)
     {
      g_st.Flush();
      Summary();
      Comment("");
     }
  }

void OnTick()
  {
   if(g_fatal != "" || (!g_ready && !Ready()))
      return;
   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t))
      return;
   g_ex.Process();
   // tiền và đối chiếu lệnh: mỗi giây một lần là đủ (tick trong cùng giây gần như không đổi gì)
   if(t.time != g_lastSec)
     {
      g_lastSec = t.time;
      CheckMoney(t.time);
      if(g_needSync || t.time - g_lastSync >= 10)
         SyncBook();
      ProcessCloses(t.time);
     }
   NewBar(t);
   if(!g_tester)
      g_st.Flush();
  }

void OnTimer()
  {
   Comment(StatusText());
   if(!g_ready)
      return;
   g_jr.Flush();
   int day = YmdKey(VnDayStart(TimeCurrent(), InpVnOffset), InpVnOffset);
   if(!g_tester && day != g_touchDay)
     {
      g_touchDay = day;
      g_st.Touch();   // terminal tự xóa dữ liệu lưu sau 4 tuần không dùng
     }
  }

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;
   g_needSync = true;
   if(g_ready && trans.deal_type == DEAL_TYPE_BALANCE && HistoryDealSelect(trans.deal))
     {
      double amount = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
      g_money.OnBalance(amount);
      g_log.Add("nap_rut", (amount >= 0 ? "Nạp " : "Rút ") + DoubleToString(MathAbs(amount), 2) + " " + AccountInfoString(ACCOUNT_CURRENCY)
                + ": dời mốc lời/lỗ ngày/tuần/tổng, không tính là lời/lỗ");
     }
  }

// Hết dữ liệu tester: ghi lệnh còn mở (lý do 4, như PhanUngLab) rồi in tổng kết
double OnTester()
  {
   if(!g_ready)
      return 0.0;
   SyncBook();
   MqlTick t;
   SymbolInfoTick(_Symbol, t);
   for(int k = 0; k < g_book.n; k++)
     {
      FvgTrade x = g_book.t[k];
      FvgExit e;
      ZeroMemory(e);
      e.known = true;
      e.time = t.time;
      e.price = x.dir > 0 ? t.bid : t.ask;
      e.reason = FX_END;
      if(x.ticket != 0 && PositionSelectByTicket(x.ticket))
         e.money = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      g_jr.Trade(x, e);
     }
   g_jr.Flush();
   Summary();
   return 0.0;
  }
