// BotLuoi: bot lưới thử nghiệm giống bot trong video nhưng an toàn hơn (SPEC §19). CHỈ ĐỂ ĐO trong Strategy Tester/demo.
// Thang lệnh chờ hai phía, lot cố định, 10 lệnh mỗi phía, không dừng lỗ từng lệnh; đóng cả rổ khi lời 1 bước, khi khớp đủ
// hai phía, khi chạm giới hạn lỗ, hoặc hết giờ chạy (00:00 VN thứ Bảy). Ghi từng rổ và bảng tổng kết vào Common\Files\BotLuoi.
#property copyright "BotVang"
#property version   "1.00"
#property description "Bot lưới thử nghiệm (SPEC §19): giống video, lot cố định, 10 lệnh mỗi phía, đóng cả rổ khi lời 1 bước. Chỉ để đo."

#include <BotVang/Grid.mqh>
#include <BotVang/Stats.mqh>

input string   InpRunName = "luoi";           // Tên lần chạy (thư mục kết quả)
input long     InpMagic = 20260928;           // Mã nhận diện lệnh (Magic)
input double   InpLot = 0.01;                 // Lot mỗi lệnh: lot nhỏ nhất của sàn hoặc gấp đôi (vàng, BTC 0.01; ETH 0.10)
input double   InpStep = 0.40;                // Bước giữa hai bậc (theo giá): vàng 0,40; BTC 20; ETH 1,8
input int      InpLevels = 10;                // Số lệnh chờ mỗi phía
input double   InpTargetSteps = 1.0;          // Đóng rổ khi lời ≥ số bước này × tiền 1 bước của 1 lệnh
input double   InpDayLoss = 10.0;             // Giới hạn lỗ ngày (% Equity đầu ngày VN)
input double   InpWeekLoss = 20.0;            // Giới hạn lỗ tuần (% Equity đầu tuần VN)
input double   InpTotalLoss = 15.0;           // Giới hạn lỗ tổng (% vốn lúc bắt đầu) → dừng hẳn
input bool     InpRestartAfterStop = false;   // Lần chạy phụ: giả sử chủ bot cho chạy lại lúc 00:00 VN hôm sau mỗi lần dừng hẳn
input int      InpVnOffset = 7;               // Giờ VN = giờ sàn + số giờ này
input datetime InpHalfVn = D'2026.04.06';     // Mốc 70a/70b (giờ VN) để chia kết quả
input datetime InpCutVn = D'2026.07.06';      // Mốc 70/30 (giờ VN)

#define R_TARGET 0   // lời đủ 1 bước
#define R_FULL   1   // khớp đủ hai phía
#define R_LIMIT  2   // chạm giới hạn lỗ
#define R_TIME   3   // hết giờ chạy
#define R_ABORT  4   // rải thiếu (sàn từ chối một lệnh chờ): gỡ cả thang
#define R_END    5   // còn mở lúc hết dữ liệu (tính lời/lỗ đang mở)
#define R_COUNT  6

CGrid    g_grid;
bool     g_ready = false;          // đã đọc được tài khoản (tick đầu khi đã kết nối)
string   g_folder;
int      g_csv = INVALID_HANDLE;
// rổ đang chạy
bool     g_open = false;           // đã rải thang
bool     g_closing = false;        // đã gửi đóng, chờ sàn xác nhận hết
int      g_reason = -1;
long     g_basketId = 0;
datetime g_basketStart = 0;
double   g_target = 0.0;
double   g_basketMin = 0.0;        // lỗ tạm sâu nhất của rổ
int      g_basketMaxPos = 0;
int      g_basketBuys = 0, g_basketSells = 0;
datetime g_retryAt = 0;
datetime g_lastCloseSend = 0;      // lúc gửi xong lượt đóng gần nhất (gửi lại tối đa 1 lần mỗi giây, chờ 2 giây cho lệnh khớp muộn)
datetime g_lastStrayClose = 0;
double   g_basketBal = 0.0;        // số dư lúc rải thang
double   g_lastFinishBal = 0.0;    // số dư lúc rổ trước xong hẳn
double   g_outside = 0.0;          // lời/lỗ phát sinh giữa hai rổ (lệnh khớp muộn đóng lúc không có rổ)
int      g_strays = 0;             // số lệnh sót đã đóng
int      g_aborts = 0;             // số thang rải thiếu
datetime g_noMarginAt = 0;         // lần đầu không đủ ký quỹ để mở 1 lệnh
int      g_noMarginChecks = 0;     // số lần (mỗi 60 giây) không rải được vì thiếu ký quỹ
datetime g_startTime = 0;          // lúc bắt đầu chạy (kiểm tra 2 chỉ cộng deal từ lúc này)
// tiền và giới hạn
double   g_startEq = 0.0;          // vốn lúc bắt đầu chạy
double   g_capital = 0.0;          // vốn gốc cho giới hạn tổng (đặt lại khi "cho chạy lại")
int      g_dayKey = 0, g_weekKey = 0;
double   g_dayEq = 0.0, g_weekEq = 0.0;
datetime g_pauseUntil = 0;
bool     g_hardStop = false;
datetime g_firstStopAt = 0;
int      g_hardStops = 0;
// thống kê
double   g_peakEq = 0.0, g_maxDd = 0.0, g_maxDdPct = 0.0, g_minEq = DBL_MAX;
datetime g_maxDdAt = 0;
long     g_baskets = 0, g_basketWins = 0;
long     g_byReason[R_COUNT];
double   g_pnlByReason[R_COUNT];
double   g_sumBaskets = 0.0;
double   g_worstBasket = 0.0, g_bestBasket = 0.0, g_worstFloat = 0.0;
int      g_maxOpen = 0;
int      g_dayLimitDays = 0, g_weekLimits = 0;
double   g_partPnl[3];
long     g_partBaskets[3];
int      g_months[];
double   g_monthPnl[];

string ReasonText(int r)
  {
   switch(r)
     {
      case R_TARGET: return "loi_1_buoc";
      case R_FULL:   return "khop_du_hai_phia";
      case R_LIMIT:  return "gioi_han_lo";
      case R_TIME:   return "het_gio";
      case R_ABORT:  return "rai_thieu";
      case R_END:    return "con_mo_cuoi_ky";
     }
   return "?";
  }

// Giờ chạy: từ 00:00 VN thứ Hai tới 00:00 VN thứ Bảy (SPEC §19)
bool InWindow(datetime server)
  {
   MqlDateTime v;
   TimeToStruct(server + InpVnOffset * 3600, v);
   return v.day_of_week >= 1 && v.day_of_week <= 5;
  }

int PartOf(datetime server)
  {
   datetime vn = server + InpVnOffset * 3600;
   return vn < InpHalfVn ? 0 : (vn < InpCutVn ? 1 : 2);
  }

void AddMonth(datetime server, double pnl)
  {
   MqlDateTime v;
   TimeToStruct(server + InpVnOffset * 3600, v);
   int key = v.year * 100 + v.mon;
   int n = ArraySize(g_months);
   for(int i = 0; i < n; i++)
      if(g_months[i] == key)
        {
         g_monthPnl[i] += pnl;
         return;
        }
   ArrayResize(g_months, n + 1);
   ArrayResize(g_monthPnl, n + 1);
   g_months[n] = key;
   g_monthPnl[n] = pnl;
  }

// Mốc Equity đầu ngày/tuần VN (tick đầu tiên sau mốc), sụt vốn so với đỉnh
void UpdateMoney(datetime now, double eq)
  {
   int dk = YmdKey(VnDayStart(now, InpVnOffset), InpVnOffset);
   if(dk != g_dayKey)
     {
      g_dayKey = dk;
      g_dayEq = eq;
      // lần chạy phụ: sang ngày VN mới sau khi dừng hẳn thì coi như chủ bot bấm cho chạy lại (vốn gốc tính lại, §11.2)
      if(g_hardStop && InpRestartAfterStop)
        {
         g_hardStop = false;
         g_capital = eq;
         PrintFormat("[BotLuoi] chay_lai | giả sử chủ bot cho chạy lại, vốn gốc mới %.2f", eq);
        }
     }
   int wk = YmdKey(VnWeekStart(now, InpVnOffset), InpVnOffset);
   if(wk != g_weekKey)
     {
      g_weekKey = wk;
      g_weekEq = eq;
     }
   if(eq > g_peakEq)
      g_peakEq = eq;
   g_minEq = MathMin(g_minEq, eq);
   double dd = g_peakEq - eq;
   if(dd > g_maxDd)
     {
      g_maxDd = dd;
      g_maxDdPct = g_peakEq > 0.0 ? 100.0 * dd / g_peakEq : 0.0;
      g_maxDdAt = now;
     }
  }

// Giới hạn lỗ §11.2: 3 = tổng (dừng hẳn), 2 = tuần, 1 = ngày, 0 = chưa
int LimitHit(double eq)
  {
   if(g_capital - eq >= InpTotalLoss / 100.0 * g_capital)
      return 3;
   if(g_dayEq - eq >= InpDayLoss / 100.0 * g_dayEq)
      return 1;
   if(g_weekEq - eq >= InpWeekLoss / 100.0 * g_weekEq)
      return 2;
   return 0;
  }

// Số lệnh và lỗ tạm của rổ (lấy mẫu cả lúc đang đóng: lệnh chờ còn có thể khớp trong lúc hủy).
// Lỗ tạm = phần đã chốt từ lúc rải thang + phần đang mở
void SampleBasket(int buys, int sells, double floating)
  {
   double pnl = AccountInfoDouble(ACCOUNT_BALANCE) - g_basketBal + floating;
   g_basketMin = MathMin(g_basketMin, pnl);
   g_basketMaxPos = MathMax(g_basketMaxPos, buys + sells);
   g_basketBuys = MathMax(g_basketBuys, buys);
   g_basketSells = MathMax(g_basketSells, sells);
   g_maxOpen = MathMax(g_maxOpen, buys + sells);
  }

// Ghi một rổ đã xong: lời/lỗ = số dư bây giờ − số dư lúc rải thang (atEnd: rổ còn mở lúc hết dữ liệu, dùng Equity)
void FinishBasket(datetime now, bool atEnd)
  {
   double pnl = (atEnd ? AccountInfoDouble(ACCOUNT_EQUITY) : AccountInfoDouble(ACCOUNT_BALANCE)) - g_basketBal;
   g_lastFinishBal = atEnd ? AccountInfoDouble(ACCOUNT_EQUITY) : AccountInfoDouble(ACCOUNT_BALANCE);
   g_baskets++;
   if(pnl > 0.0)
      g_basketWins++;
   g_byReason[g_reason]++;
   g_pnlByReason[g_reason] += pnl;
   g_sumBaskets += pnl;
   g_worstBasket = MathMin(g_worstBasket, pnl);
   g_bestBasket = MathMax(g_bestBasket, pnl);
   g_worstFloat = MathMin(g_worstFloat, g_basketMin);
   int part = PartOf(now);
   g_partPnl[part] += pnl;
   g_partBaskets[part]++;
   AddMonth(now, pnl);
   if(g_csv != INVALID_HANDLE)
      FileWriteString(g_csv, StringFormat("%I64d;%s;%s;%d;%s;%d;%d;%d;%.2f;%.2f\r\n", g_basketId,
                      TimeToString(g_basketStart + InpVnOffset * 3600, TIME_DATE | TIME_SECONDS),
                      TimeToString(now + InpVnOffset * 3600, TIME_DATE | TIME_SECONDS), (int)((now - g_basketStart) / 60),
                      ReasonText(g_reason), g_basketBuys, g_basketSells, g_basketMaxPos, pnl, g_basketMin));
   g_open = false;
   g_closing = false;
   g_reason = -1;
  }

// Gửi đóng cả rổ; mốc chờ tính từ lúc gửi xong (khớp có độ trễ thì lượt gửi kéo dài nhiều giây)
void SendClose(void)
  {
   if(!g_grid.CloseAll())
      Print("[BotLuoi] loi_dong_ro | ", g_grid.lastError);
   g_lastCloseSend = TimeCurrent();
  }

void StartClose(int reason)
  {
   g_reason = reason;
   g_closing = true;
   SendClose();
  }

int OnInit()
  {
   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(MathAbs(InpLot - vmin) > 1e-9 && MathAbs(InpLot - 2 * vmin) > 1e-9)
     {
      Print("[BotLuoi] ", _Symbol, ": lot chỉ được ", DoubleToString(vmin, 2), " hoặc ", DoubleToString(2 * vmin, 2));
      return INIT_PARAMETERS_INCORRECT;
     }
   if(InpLevels < 1 || InpStep <= 0.0 || InpTargetSteps < 0.0)
      return INIT_PARAMETERS_INCORRECT;
   string why;
   if(!g_grid.Init(_Symbol, InpMagic, InpStep, InpLevels, InpLot, why))
     {
      Print("[BotLuoi] khong_khoi_dong | ", why);
      return INIT_FAILED;
     }
   ArrayInitialize(g_byReason, 0);
   ArrayInitialize(g_pnlByReason, 0.0);
   ArrayInitialize(g_partPnl, 0.0);
   ArrayInitialize(g_partBaskets, 0);
   g_folder = "BotLuoi\\" + InpRunName + "_" + _Symbol + "\\";
   g_csv = FileOpen(g_folder + "ro.csv", FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON, 0, CP_UTF8);
   if(g_csv == INVALID_HANDLE)
      Print("[BotLuoi] khong_ghi_duoc ro.csv err=", GetLastError());
   else
      FileWriteString(g_csv, "ro;bat_dau_vn;ket_thuc_vn;phut;ly_do;so_mua;so_ban;lenh_mo_nhieu_nhat;loi_lo;lo_tam_sau_nhat\r\n");
   return INIT_SUCCEEDED;
  }

// Tick đầu khi đã kết nối sàn: kiểu tài khoản và vốn chỉ đọc đúng lúc này (OnInit có thể chạy trước khi đăng nhập)
bool Ready(void)
  {
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq <= 0.0 || (!MQLInfoInteger(MQL_TESTER) && !TerminalInfoInteger(TERMINAL_CONNECTED)))
      return false;
   if(!CGrid::HedgingOk())
     {
      Print("[BotLuoi] khong_khoi_dong | tài khoản không phải kiểu hedging: không giữ được MUA và BÁN cùng lúc");
      ExpertRemove();
      return false;
     }
   g_startEq = eq;
   g_capital = eq;
   g_startTime = TimeCurrent();
   g_peakEq = eq;
   g_lastFinishBal = AccountInfoDouble(ACCOUNT_BALANCE);
   g_ready = true;
   PrintFormat("[BotLuoi] khoi_dong | %s: bước %s, %d lệnh mỗi phía, lot %.2f, đóng rổ khi lời %.1f bước; vốn %.2f %s%s",
               _Symbol, DoubleToString(InpStep, _Digits), InpLevels, InpLot, InpTargetSteps, eq, AccountInfoString(ACCOUNT_CURRENCY),
               InpRestartAfterStop ? " (lần chạy phụ: cho chạy lại sau mỗi lần dừng hẳn)" : "");
   return true;
  }

void OnTick()
  {
   if(!g_ready && !Ready())
      return;
   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t))
      return;
   datetime now = t.time;
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   UpdateMoney(now, eq);
   int buys, sells, pending, strays;
   double pnl;
   g_grid.Count(buys, sells, pending, pnl, strays);
   int all = buys + sells + pending + strays;
   // Đang đóng: còn lệnh thì gửi lại (tối đa 1 lần mỗi giây); hết lệnh đủ 2 giây sau lượt gửi cuối (lệnh chờ khớp muộn vì độ
   // trễ còn có thể hiện ra) thì ghi rổ rồi xét rải thang mới ngay trong tick này
   if(g_closing)
     {
      SampleBasket(buys, sells, pnl);
      if(all > 0)
        {
         if(TimeCurrent() - g_lastCloseSend >= 1)
            SendClose();
         return;
        }
      if(TimeCurrent() - g_lastCloseSend < 2)
         return;
      FinishBasket(now, false);
     }
   else
      if(!g_open && all > 0)
        {
         // giữa hai rổ mà còn lệnh (khớp muộn hơn 2 giây): đóng hết trước khi rải thang mới
         if(TimeCurrent() - g_lastCloseSend >= 1)
           {
            SendClose();
            g_strays += g_grid.lastClosed;
           }
         return;
        }
   int hit = LimitHit(eq);
   if(hit == 3 && !g_hardStop)
     {
      g_hardStop = true;
      g_hardStops++;
      if(g_firstStopAt == 0)
         g_firstStopAt = now;
      PrintFormat("[BotLuoi] dung_han | lỗ tổng chạm %.0f%%: Equity %.2f / vốn gốc %.2f", InpTotalLoss, eq, g_capital);
     }
   else
      if((hit == 1 || hit == 2) && now >= g_pauseUntil)
        {
         datetime nextDay = VnDayStart(now, InpVnOffset) + 86400;
         datetime nextWeek = VnWeekStart(now, InpVnOffset) + 7 * 86400;
         g_pauseUntil = hit == 1 ? nextDay : nextWeek;
         if(hit == 1)
            g_dayLimitDays++;
         else
            g_weekLimits++;
         PrintFormat("[BotLuoi] nghi | chạm giới hạn lỗ %s: Equity %.2f, nghỉ tới %s VN", hit == 1 ? "ngày" : "tuần", eq,
                     TimeToString(g_pauseUntil + InpVnOffset * 3600, TIME_DATE | TIME_MINUTES));
        }
   bool blocked = g_hardStop || now < g_pauseUntil;
   bool window = InWindow(now);
   if(g_open)
     {
      if(strays > 0 && TimeCurrent() - g_lastStrayClose >= 1)
        {
         g_strays += g_grid.CloseStrays();
         g_lastStrayClose = TimeCurrent();
        }
      SampleBasket(buys, sells, pnl);
      // hết giờ: ngoài giờ chạy, hoặc rổ từ tuần trước còn sót (không có giá nào trong cuối tuần để đóng đúng 00:00 thứ Bảy)
      bool timeUp = !window || VnWeekStart(now, InpVnOffset) != VnWeekStart(g_basketStart, InpVnOffset);
      if(blocked)
         StartClose(R_LIMIT);
      else
         if(timeUp)
            StartClose(R_TIME);
         else
            if(buys + sells > 0 && pnl >= g_target)
               StartClose(R_TARGET);
            else
               if(buys >= InpLevels && sells >= InpLevels)
                  StartClose(R_FULL);
      return;
     }
   if(blocked || !window || now < g_retryAt)
      return;
   // Không đủ ký quỹ để mở dù 1 lệnh: không rải thang, ghi lại lần đầu gặp
   if(AccountInfoDouble(ACCOUNT_MARGIN_FREE) < g_grid.MarginOne(t.ask))
     {
      g_noMarginChecks++;
      if(g_noMarginAt == 0)
        {
         g_noMarginAt = now;
         PrintFormat("[BotLuoi] het_ky_quy | Equity %.2f không đủ ký quỹ cho 1 lệnh: ngừng rải thang", eq);
        }
      g_retryAt = now + 60;
      return;
     }
   // Rải thang mới. Tiền phát sinh giữa hai rổ (nếu có) ghi riêng. Rải thiếu (sàn từ chối một lệnh chờ, thường vì giá đã chạy qua
   // mức đặt trong lúc gửi) thì gỡ cả thang, ghi thành một rổ lý do "rải thiếu", thử lại sau 60 giây
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   int placed = g_grid.Build(t);
   if(placed == 0)
     {
      g_retryAt = now + 60;   // sàn chưa nhận lệnh nào (ví dụ đang không cho giao dịch): không tính là rổ
      return;
     }
   g_outside += bal - g_lastFinishBal;
   g_lastFinishBal = bal;
   g_open = true;
   g_basketId++;
   g_basketStart = now;
   g_basketBal = bal;
   g_target = InpTargetSteps * g_grid.StepMoney(t.ask);
   g_basketMin = 0.0;
   g_basketMaxPos = 0;
   g_basketBuys = 0;
   g_basketSells = 0;
   if(placed < 2 * InpLevels)
     {
      g_aborts++;
      g_retryAt = now + 60;
      StartClose(R_ABORT);
     }
  }

string Money(double v) { return (v >= 0 ? "+" : "") + DoubleToString(v, 2); }

// Kiểm tra độc lập: cộng mọi deal của bot từ lúc bắt đầu chạy + lời/lỗ các lệnh còn mở
double DealsTotal(void)
  {
   double sum = 0.0;
   if(HistorySelect(g_startTime, TimeCurrent() + 1))
      for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
        {
         ulong d = HistoryDealGetTicket(i);
         if(d == 0 || HistoryDealGetInteger(d, DEAL_MAGIC) != InpMagic || HistoryDealGetString(d, DEAL_SYMBOL) != _Symbol)
            continue;
         sum += HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_SWAP) + HistoryDealGetDouble(d, DEAL_COMMISSION)
                + HistoryDealGetDouble(d, DEAL_FEE);
        }
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk != 0 && PositionGetInteger(POSITION_MAGIC) == InpMagic && PositionGetString(POSITION_SYMBOL) == _Symbol)
         sum += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
     }
   return sum;
  }

string Check(double a, double b) { return MathAbs(a - b) < 0.05 ? "KHỚP" : "LỆCH " + DoubleToString(a - b, 2); }

// Bảng tổng kết: in ra log tester và ghi tong_ket.txt
void Summary()
  {
   string cur = AccountInfoString(ACCOUNT_CURRENCY);
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double change = eq - g_startEq;
   string lines[];
   int n = 0;
   string parts[3] = {"70a", "70b", "30"};
   ArrayResize(lines, 40);
   lines[n++] = StringFormat("%s %s: vốn %.2f -> %.2f %s, lời/lỗ ròng %s (%.1f%%)", InpRunName, _Symbol, g_startEq, eq, cur,
                             Money(change), g_startEq > 0.0 ? 100.0 * change / g_startEq : 0.0);
   lines[n++] = StringFormat("Sụt sâu nhất so với đỉnh: %.2f %s (%.1f%%) lúc %s VN; Equity thấp nhất %.2f", g_maxDd, cur, g_maxDdPct,
                             TimeToString(g_maxDdAt + InpVnOffset * 3600, TIME_DATE | TIME_MINUTES), g_minEq);
   lines[n++] = StringFormat("Rổ: %I64d, lời %I64d (%.1f%%); rổ tốt nhất %s, tệ nhất %s; lỗ tạm sâu nhất của một rổ %s; lệnh mở cùng lúc nhiều nhất %d",
                             g_baskets, g_basketWins, g_baskets > 0 ? 100.0 * g_basketWins / g_baskets : 0.0, Money(g_bestBasket),
                             Money(g_worstBasket), Money(g_worstFloat), g_maxOpen);
   for(int r = 0; r < R_COUNT; r++)
      lines[n++] = StringFormat("  đóng vì %-17s: %6I64d rổ, tổng %s", ReasonText(r), g_byReason[r], Money(g_pnlByReason[r]));
   lines[n++] = StringFormat("Chạm giới hạn ngày %d lần, tuần %d lần; dừng hẳn %d lần%s", g_dayLimitDays, g_weekLimits, g_hardStops,
                             g_firstStopAt > 0 ? ", lần đầu lúc " + TimeToString(g_firstStopAt + InpVnOffset * 3600, TIME_DATE | TIME_MINUTES) + " VN" : "");
   if(g_noMarginAt > 0)
      lines[n++] = StringFormat("Không đủ ký quỹ để mở dù 1 lệnh: lần đầu lúc %s VN; tổng cộng %d lần kiểm (mỗi 60 giây) không rải được. "
                                "Tháng không có rổ nào thì không có trong dòng 'Theo tháng'",
                                TimeToString(g_noMarginAt + InpVnOffset * 3600, TIME_DATE | TIME_MINUTES), g_noMarginChecks);
   for(int p = 0; p < 3; p++)
      lines[n++] = StringFormat("  phần %-3s: %6I64d rổ, lời/lỗ %s", parts[p], g_partBaskets[p], Money(g_partPnl[p]));
   string months = "Theo tháng:";
   for(int i = 0; i < ArraySize(g_months); i++)
      months += StringFormat(" %d/%02d %s;", g_months[i] % 100, g_months[i] / 100 % 100, Money(g_monthPnl[i]));
   lines[n++] = months;
   // Kiểm tra 1 (SPEC §19): tổng các rổ = Equity thay đổi; phần lệch là tiền ngoài rổ (lệnh khớp muộn đóng giữa hai rổ)
   double outside = g_outside + (g_open || g_closing ? 0.0 : eq - g_lastFinishBal);
   lines[n++] = StringFormat("Kiểm tra 1: tổng các rổ %s, Equity thay đổi %s -> %s%s", Money(g_sumBaskets), Money(change),
                             Check(g_sumBaskets, change), MathAbs(outside) >= 0.05 ? " (tiền ngoài rổ " + Money(outside) + ")" : "");
   // Kiểm tra 2 (độc lập): cộng lại toàn bộ lịch sử deal của bot
   double deals = DealsTotal();
   lines[n++] = StringFormat("Kiểm tra 2: cộng lịch sử deal của bot %s, Equity thay đổi %s -> %s", Money(deals), Money(change), Check(deals, change));
   lines[n++] = StringFormat("Thang rải thiếu (gỡ, thử lại sau 60 giây): %d; lệnh sót (khớp muộn, không thuộc rổ đang chạy) đã đóng: %d", g_aborts, g_strays);
   lines[n++] = StringFormat("Sàn từ chối yêu cầu: %d lần%s", g_grid.rejects, g_grid.lastError != "" ? " (lần cuối: " + g_grid.lastError + ")" : "");
   int h = FileOpen(g_folder + "tong_ket.txt", FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON, 0, CP_UTF8);
   for(int i = 0; i < n; i++)
     {
      Print("[BotLuoi] ", lines[i]);
      if(h != INVALID_HANDLE)
         FileWriteString(h, lines[i] + "\r\n");
     }
   if(h != INVALID_HANDLE)
      FileClose(h);
  }

// Rổ còn mở lúc hết dữ liệu: ghi với lời/lỗ đang mở để các con số cộng lại bằng Equity cuối
void FinishOpenBasket(void)
  {
   if(!g_open && !g_closing)
      return;
   int buys, sells, pending, strays;
   double pnl;
   g_grid.Count(buys, sells, pending, pnl, strays);
   SampleBasket(buys, sells, pnl);
   g_reason = R_END;
   FinishBasket(TimeCurrent(), true);
  }

double OnTester()
  {
   FinishOpenBasket();
   Summary();
   return AccountInfoDouble(ACCOUNT_EQUITY) - g_startEq;
  }

void OnDeinit(const int reason)
  {
   if(!MQLInfoInteger(MQL_TESTER) && g_ready)
     {
      FinishOpenBasket();
      Summary();
     }
   if(g_csv != INVALID_HANDLE)
      FileClose(g_csv);
  }
