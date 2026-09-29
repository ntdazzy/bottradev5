// BotVang: bot 1 lệnh đi theo đà trên XAUUSD (Exness, MT5), dời dừng lỗ theo bước, đảo chiều mặc định TẮT (SPEC v2).
// Không phải bot lưới, không nhồi lệnh, không gấp thếp. Tín hiệu vào lệnh dùng chung code với BotVangLab.
// Mặc định bot khởi động ở trạng thái TẮT: luật vào lệnh chưa được BotVangLab chứng minh có lợi thế (xem docs/HANDOFF.md).
#property copyright "BotVang"
#property version   "2.00"
#property description "Bot vàng 1 lệnh, dời dừng lỗ theo bước (SPEC v2). Mặc định TẮT: chỉ chạy demo cho tới khi Lab chứng minh có lợi thế."

#include <BotVang/Engine.mqh>
#include <BotVang/Panel.mqh>
#include <BotVang/Journal.mqh>

input group "Chung"
input long     InpMagic = 20260927;              // Mã nhận diện lệnh của bot (Magic)
input double   InpLot = 0.01;                    // Khối lượng: lot nhỏ nhất hoặc gấp đôi (vàng, BTC 0.01/0.02; ETH 0.10/0.20)
input bool     InpStartOn = false;               // Bật bot ngay khi khởi động (mặc định TẮT)
input group "Giờ chạy (giờ VN = giờ sàn + chênh lệch)"
input bool     InpTimeFilter = true;             // Lọc giờ chạy
input int      InpStartMinVn = 840;              // Từ phút (840 = 14:00)
input int      InpEndMinVn = 1440;               // Tới phút (1440 = 24:00)
input int      InpVnOffset = 7;                  // Chênh lệch giờ VN so với giờ sàn
input int      InpBreakCloseMin = 30;            // Đóng/không vào khi còn <= số phút tới giờ nghỉ của sàn
input int      InpAfterOpenMin = 15;             // Không vào khi sàn vừa mở lại chưa quá số phút
input bool     InpSpecSummer = true;             // Chỉ khi chạy tester: lịch phiên trong terminal đang theo giờ hè Mỹ
input group "Vào lệnh (§7.1)"
input ENUM_BIAS_MODE InpBiasMode = BIAS_H4_H1;   // Hướng lớn
input int      InpMinEntryScore = 4;             // Điểm vùng tối thiểu
input int      InpStrongScore = 6;               // Điểm của cản mạnh
input double   InpMinRoomB = 2.0;                // Khoảng tới cản mạnh đối diện >= x × B
input bool     InpAllowFresh = false;            // Vào cả vùng còn mới chưa lật (tùy chọn §7.1)
input group "Chạy lệnh (§8, §9)"
input double   InpStepAtrMult = 0.8;             // B = max(x × ATR(M5), ...)
input double   InpStepMinSpreadMult = 5.0;       // ... , y × chênh lệch)
input double   InpLockDistB = 1.0;               // Cách mép cản mạnh < x × B thì khóa lời
input double   InpLockOffsetB = 0.5;             // Khóa lời: dừng lỗ cách giá x × B
input int      InpMaxBarsInZone = 6;             // Nằm trong dải cản quá số nến này thì không đảo
input group "Đảo chiều (§10) — mặc định TẮT"
input ENUM_FLIP_MODE InpFlipMode = FLIP_OFF;     // Chế độ đảo chiều
input int      InpBrakeLosses = 2;               // Số lần dừng lỗ lỗ tiền liên tiếp thì NGHỈ
input int      InpBrakeMinutes = 30;             // NGHỈ bao nhiêu phút
input group "Rủi ro và giới hạn lỗ (§11)"
input double   InpRiskPct = 0.5;                 // Rủi ro mỗi lệnh tối đa (% Equity)
input double   InpSlipBuffer = 0.5;              // Đệm trượt giá (theo giá) trong rủi ro
input ENUM_LIMIT_UNIT InpLimitUnit = LIMIT_PERCENT; // Giới hạn tính theo % hay tiền
input double   InpDayLoss = 10.0;                // Giới hạn lỗ ngày
input double   InpWeekLoss = 20.0;               // Giới hạn lỗ tuần
input double   InpTotalLoss = 15.0;              // Giới hạn lỗ tổng (dừng hẳn)
input bool     InpProfitTarget = false;          // Bật mục tiêu lời ngày/tuần
input double   InpDayProfit = 0.0;               // Mục tiêu lời ngày (0 = không)
input double   InpWeekProfit = 0.0;              // Mục tiêu lời tuần (0 = không)
input double   InpMinFreeMarginPct = 50.0;       // Ký quỹ trống sau lệnh >= % Equity
input double   InpMinMarginLevel = 500.0;        // Mức ký quỹ sau lệnh >= %
input group "Bộ lọc (§12)"
input double   InpMaxSpread = 0.5;               // Chênh lệch tối đa (giá)
input bool     InpNewsFilter = true;             // Lọc tin mạnh USD
input int      InpNewsBefore = 5;                // Phút trước tin
input int      InpNewsAfter = 10;                // Phút sau tin
input int      InpFomcAfter = 60;                // Phút sau quyết định lãi suất Fed / họp báo
input group "Trượt giá (§13.3)"
input double   InpMaxEntrySlipB = 0.5;           // Trượt khi vào > x × B thì đóng ngay và NGHỈ
input double   InpMaxSlSlipB = 1.0;              // Trượt khi dính dừng lỗ > x × B thì NGHỈ
input int      InpSlipPauseMin = 15;             // NGHỈ bao nhiêu phút sau trượt mạnh
input group "Hiển thị"
input bool     InpShowPanel = true;              // Hiện bảng điều khiển
input bool     InpDrawZones = true;              // Vẽ vùng
input bool     InpWriteJournal = true;           // Ghi nhật ký file MQL5/Files/BotVang

CEngine  g_e;
CPanel   g_panel;
CJournal g_log;
bool     g_ready = false;
datetime g_lastDraw = 0;
string   g_initError = "";

int OnInit()
  {
   // Lot = lot nhỏ nhất của sàn hoặc gấp đôi (vàng, BTC: 0.01/0.02; ETH: 0.10/0.20). Không bao giờ tự tăng/giảm (SPEC §2)
   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(MathAbs(InpLot - vmin) > 1e-9 && MathAbs(InpLot - 2 * vmin) > 1e-9)
     {
      Print("[BotVang] ", _Symbol, ": khối lượng chỉ được ", DoubleToString(vmin, 2), " hoặc ", DoubleToString(2 * vmin, 2),
            " (lot nhỏ nhất của sàn hoặc gấp đôi, SPEC §2); đang đặt ", DoubleToString(InpLot, 2));
      return INIT_PARAMETERS_INCORRECT;
     }
   g_ready = false;   // đổi khung/đổi tham số: EA không nạp lại từ đầu nên phải nạp vùng lại
   g_log.Init(InpWriteJournal, InpVnOffset);
   BotSettings s;
   s.magic = InpMagic;
   s.lot = InpLot;
   s.allowFresh = InpAllowFresh;
   s.biasMode = InpBiasMode;
   s.minEntryScore = InpMinEntryScore;
   s.strongScore = InpStrongScore;
   s.minRoomB = InpMinRoomB;
   s.stepAtrMult = InpStepAtrMult;
   s.stepMinSpreadMult = InpStepMinSpreadMult;
   s.lockDistB = InpLockDistB;
   s.lockOffsetB = InpLockOffsetB;
   s.maxBarsInZone = InpMaxBarsInZone;
   s.brakeLosses = InpBrakeLosses;
   s.brakeMinutes = InpBrakeMinutes;
   s.riskPct = InpRiskPct;
   s.slipBuffer = InpSlipBuffer;
   s.limitUnit = InpLimitUnit;
   s.dayLoss = InpDayLoss;
   s.weekLoss = InpWeekLoss;
   s.totalLoss = InpTotalLoss;
   s.profitTargetOn = InpProfitTarget;
   s.dayProfit = InpDayProfit;
   s.weekProfit = InpWeekProfit;
   s.minFreeMarginPct = InpMinFreeMarginPct;
   s.minMarginLevel = InpMinMarginLevel;
   s.newsBefore = InpNewsBefore;
   s.newsAfter = InpNewsAfter;
   s.fomcAfter = InpFomcAfter;
   s.maxEntrySlipB = InpMaxEntrySlipB;
   s.maxSlSlipB = InpMaxSlSlipB;
   s.slipPauseMinutes = InpSlipPauseMin;
   g_e.s = s;
   g_e.mc.timeFilter = InpTimeFilter;
   g_e.mc.vnOffset = InpVnOffset;
   g_e.mc.startMin = InpStartMinVn;
   g_e.mc.endMin = InpEndMinVn;
   g_e.mc.breakCloseMin = InpBreakCloseMin;
   g_e.mc.afterOpenMin = InpAfterOpenMin;
   g_e.mc.maxSpread = InpMaxSpread;
   g_e.mc.newsFilter = InpNewsFilter;
   g_e.mc.newsRequired = !MQLInfoInteger(MQL_TESTER);   // chạy thật: bật lọc tin mà không có lịch tin thì không vào (§12.2)
   g_e.mc.specIsSummer = MQLInfoInteger(MQL_TESTER) && InpSpecSummer;
   g_e.botOn = InpStartOn;
   g_e.flipMode = InpFlipMode;
   g_e.lotSize = InpLot;
   if(!g_e.Init(_Symbol, GetPointer(g_log), g_initError))
     {
      g_log.Add("khong_khoi_dong", g_initError);
      return INIT_FAILED;
     }
   if(InpShowPanel)
      g_panel.Init();
   EventSetMillisecondTimer(200);
   g_log.Add("khoi_dong", "BotVang v2 trên " + _Symbol + ", Magic " + (string)InpMagic + ", bot " + (g_e.botOn ? "BẬT" : "TẮT")
             + ", lịch tin: " + (g_e.news.available ? "có" : "KHÔNG CÓ"));
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   g_e.Release();
   if(InpShowPanel)
      g_panel.Destroy();
  }

void OnTick()
  {
   if(!g_ready)
     {
      if(!g_e.Ready())
         return;
      g_e.Warmup();
      g_ready = true;
     }
   g_e.OnTick();
   if(InpDrawZones && (MQLInfoInteger(MQL_VISUAL_MODE) || !MQLInfoInteger(MQL_TESTER)) && iTime(_Symbol, PERIOD_M5, 0) != g_lastDraw)
     {
      g_lastDraw = iTime(_Symbol, PERIOD_M5, 0);
      g_panel.DrawZones(g_e.zones, InpStrongScore, TimeCurrent());
     }
  }

void OnTimer()
  {
   if(!g_ready)
      return;
   g_e.OnTimer();
   static ulong last = 0;
   if(InpShowPanel && GetTickCount64() - last >= 1000)
     {
      last = GetTickCount64();
      g_e.UpdateState(TimeCurrent());
      g_e.money.CountToday(TimeCurrent());
      g_panel.Update(g_e, g_log, TimeCurrent());
     }
  }

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  {
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD && trans.deal > 0)
      g_e.OnDeal(trans.deal);
  }

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(id == CHARTEVENT_OBJECT_CLICK && InpShowPanel && g_panel.OnClick(sparam, g_e))
     {
      g_e.UpdateState(TimeCurrent());
      g_panel.Update(g_e, g_log, TimeCurrent());
     }
  }
