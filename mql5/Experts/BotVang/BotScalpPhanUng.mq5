// §26: bot thử nghiệm phản ứng theo cản; cùng EA dùng trong máy thử và demo.
#property copyright "BotVang"
#property version "1.20"
#property description "Điểm vào theo phản ứng/lệnh chờ, chốt theo cản, bảo vệ giá vào. Mặc định TẮT, chỉ demo."

#include <Trade/Trade.mqh>
#include <BotVang/ScalpSignal.mqh>
#include <BotVang/ScalpReport.mqh>
#include <BotVang/Stats.mqh>
#include <BotVang/Journal.mqh>
#include <BotVang/Filters.mqh>

input bool             InpEnabled = false;       // Chỉ tự bật trên tài khoản demo sau khi xem kết quả
input string           InpRunName = "scalp_v3";  // Tên thư mục kết quả (máy thử)
input bool             InpExportCandles = false;// Xuất nến M1 để nghiên cứu, không đổi quyết định
input ENUM_SCALP_ENTRY  InpEntry = SCALP_AUTO;    // 0 ngay sau nến, 1 chờ hồi, 2 tự chọn
input bool             InpEarlyWick = true;      // Tự chọn: cho vào lúc râu đang rút (chỉ dữ liệu đã thấy)
input bool             InpManage = true;         // Bảo vệ giá vào, siết theo nến, thoát sớm
input long             InpMagic = 20261001;      // Mã riêng cho bot này
input double           InpMinRatio = 1.2;        // Tỷ lệ lời/lỗ sau chi phí tối thiểu (ứng viên)
input double           InpSlip = 0.5;            // Đệm trượt mỗi chặng thị trường (giá, ứng viên)
input int              InpMaxMinutes = 10;       // Giữ 1–10 phút tối đa, không giữ theo nhịp dài
input int              InpPendingMinutes = 3;    // Hạn chờ: mặc định giữ 3, thử riêng 1 phút để kiểm tra tín hiệu cũ
input double           InpRiskPct = 0.5;         // Lỗ dự kiến tối đa mỗi lệnh (% vốn hiện có)
input double           InpDayLoss = 10.0;        // Giới hạn lỗ ngày (giờ VN)
input double           InpWeekLoss = 20.0;       // Giới hạn lỗ tuần
input double           InpTotalLoss = 15.0;      // Giới hạn lỗ tổng, lưu qua khởi động lại

#define SCALP_LOT 0.01
#define SCALP_VN 7

CScalpContext g_ctx;
CScalpReport  g_report;
CState        g_state;
CMoney        g_money;
BotSettings   g_settings;
CTrade        g_trade;
CJournal      g_log;
ScalpSignal   g_signal;
bool          g_ready = false, g_tester = false, g_needSync = true, g_havePlan = false, g_lockOwned = false, g_disconnected = false;
datetime      g_bar = 0, g_lastClosed = 0, g_attempt = 0, g_second = 0, g_started = 0, g_retry = 0, g_rejectBar = 0;
datetime      g_previousTick = 0, g_gapBar = 0;
datetime      g_flatSince = 0;
ulong         g_position = 0, g_order = 0, g_seenPosition = 0;
int           g_dir = 0, g_days = 0, g_day = 0, g_signals = 0, g_rejected = 0, g_sent = 0, g_cancelled = 0;
int           g_errors = 0, g_checks = 0, g_be = 0, g_trailing = 0, g_earlyExit = 0;
double        g_tickSize = 0.0, g_peak = 0.0, g_drawdown = 0.0, g_startBalance = 0.0;
string        g_last = "Chờ dữ liệu", g_lock = "";
long          g_login = 0;
string        g_server = "";

double Price(double x) { return NormalizeDouble(MathRound(x / g_tickSize) * g_tickSize, _Digits); }
double MinDistance()
  {
   return MathMax((double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL),
                  (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL)) * _Point + g_tickSize;
  }
void Note(string event, string detail)
  {
   g_last = detail; g_report.Add(event, detail);
   if(!g_tester || event == "loi") g_log.Add(event, detail);
  }
bool ResultOk(bool sent)
  {
   uint rc = g_trade.ResultRetcode();
   if(sent && (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_PLACED || rc == TRADE_RETCODE_DONE_PARTIAL
               || rc == TRADE_RETCODE_NO_CHANGES)) return true;
   g_errors++;
   Note("loi", "module=BotScalpPhanUng retcode=" + (string)rc + " " + g_trade.ResultRetcodeDescription());
   return false;
  }

bool AcquireLock()
  {
   if(g_tester) return true;
   g_lock = "BSP_" + (string)AccountInfoInteger(ACCOUNT_LOGIN) + "_" + _Symbol;
   if(!GlobalVariableCheck(g_lock)) GlobalVariableTemp(g_lock);
   double owner = GlobalVariableGet(g_lock);
   for(long chart = ChartFirst(); chart >= 0; chart = ChartNext(chart))
      if((double)chart == owner && chart != ChartID()) return false;
   g_lockOwned = GlobalVariableSetOnCondition(g_lock, (double)ChartID(), owner);
   return g_lockOwned;
  }

void SavePlan(const ScalpSignal &s, const ScalpPlan &p, datetime expires)
  {
   g_signal = s; g_havePlan = true;
   g_state.Set("s_sl", p.sl); g_state.Set("s_tp", p.tp); g_state.Set("s_risk", MathAbs(p.entry - p.sl));
   g_state.Set("s_bar", (double)s.bar); g_state.Set("s_dir", s.dir); g_state.Set("s_exp", (double)expires);
   g_state.Set("s_price", p.entry); g_state.Set("s_be", 0); g_state.Set("s_close", 0);
   g_state.Set("s_rules", 3); g_state.Set("s_atr", s.atr); g_state.Set("s_guard", 0);
   g_state.Set("s_limit", p.limit ? 1.0 : 0.0);
   g_state.Flush();
  }

void Sync()
  {
   bool wasOccupied = g_position != 0 || g_order != 0;
   g_position = g_order = 0; g_dir = 0;
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0 || PositionGetInteger(POSITION_MAGIC) != InpMagic || PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      count++; g_position = t;
      g_dir = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 1 : -1;
     }
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong t = OrderGetTicket(i);
      if(t != 0 && OrderGetInteger(ORDER_MAGIC) == InpMagic && OrderGetString(ORDER_SYMBOL) == _Symbol)
        { count++; g_order = t; }
     }
   if(count > 1) { g_checks++; g_state.Set("s_uncert", 1); Note("loi", "Nhiều hơn một lệnh: khóa mở thêm, cần kiểm tra"); }
   if(count == 1) g_state.Set("s_wait", 0);
   if(count == 0 && g_state.Get("s_wait") != 0.0)
     {
      ulong acknowledged = (ulong)g_state.Get("s_ack");
      // Lệnh có thể đã khớp rồi đóng trước sự kiện kế tiếp. Chỉ mở khóa khi có bằng chứng ở lịch sử.
      if(acknowledged > 0 && HistoryOrderSelect(acknowledged)) g_state.Set("s_wait", 0);
     }
   if(g_position != 0 && g_position != g_seenPosition && PositionSelectByTicket(g_position))
     {
      double fill = PositionGetDouble(POSITION_PRICE_OPEN), sl = PositionGetDouble(POSITION_SL), tp = PositionGetDouble(POSITION_TP);
      // Có giá khớp nhưng thiếu kế hoạch/khác lệnh: chỉ giữ bảo vệ sàn và thoát có hạn; không đoán lại rủi ro ban đầu.
       if(g_state.Get("s_sl", 0) <= 0.0 || g_state.Get("s_rules") != 3.0
          || (g_state.Get("s_pos", 0) != 0.0 && g_state.Get("s_pos") != (double)g_position))
        { g_state.Set("s_uncert", 1); Note("loi", "Thiếu kế hoạch lệnh đang mở: khóa mở mới"); }
      else
        {
         g_state.Set("s_risk", MathAbs(fill - g_state.Get("s_sl")));
         double rr = ScalpNetRatio(g_dir, fill, g_state.Get("s_sl"), tp, InpSlip);
          if(rr + 1e-6 < InpMinRatio && !g_state.Get("s_be"))
            { g_state.Set("s_close", 1); Note("dong", "Giá khớp làm tỷ lệ thấp hơn mức chọn: đóng"); }
          if(g_state.Get("s_risk") > SCALP_MAX_RISK_ATR * g_state.Get("s_atr") + g_tickSize)
            { g_state.Set("s_close", 1); Note("dong", "Giá khớp làm dừng quá xa cho M1: đóng"); }
          if(g_state.Get("s_limit") != 0.0 && PositionGetInteger(POSITION_TIME) >= (long)g_state.Get("s_exp"))
            { g_state.Set("s_close", 1); Note("dong", "Lệnh chờ khớp sau hạn bot: đóng, vẫn ghi đủ kết quả"); }
        }
      if(sl <= 0.0 || tp <= 0.0) { g_state.Set("s_close", 1); Note("loi", "Lệnh thiếu dừng lỗ/chốt lời: đóng"); }
      g_state.Set("s_pos", (double)g_position);
      g_seenPosition = g_position;
      Note("khop", StringFormat("%s gia %s, dung %s, chot %s", g_dir > 0 ? "MUA" : "BAN",
         DoubleToString(fill, _Digits), DoubleToString(sl, _Digits), DoubleToString(tp, _Digits)));
     }
   if(count == 0 && g_seenPosition != 0)
     {
      g_state.Del("s_pos"); g_state.Del("s_close"); g_seenPosition = 0; g_havePlan = false;
     }
   if(count == 0 && wasOccupied) g_flatSince = TimeCurrent();
   g_needSync = false;
  }

bool Blocked(datetime now)
  {
   return g_state.Get(SK_HARD) != 0.0 || now < (datetime)g_state.Get(SK_PAUSE)
          || g_state.Get("s_uncert") != 0.0 || g_state.Get("s_wait") != 0.0;
  }
void CheckMoney(datetime now)
  {
   g_money.Update(now);
   int hit = g_money.LimitHit(g_settings);
   if(hit == 3 && g_state.Get(SK_HARD) == 0.0)
     { g_state.Set(SK_HARD, 1); Note("gioi_han", "Lỗ tổng chạm giới hạn, dừng hẳn"); }
   if((hit == 1 || hit == 2) && now >= (datetime)g_state.Get(SK_PAUSE))
     {
      g_state.Set(SK_PAUSE, (double)(hit == 1 ? VnDayStart(now, SCALP_VN) + 86400 : VnWeekStart(now, SCALP_VN) + 7 * 86400));
      Note("gioi_han", hit == 1 ? "Chạm lỗ ngày" : "Chạm lỗ tuần");
     }
   if(g_state.Get(SK_HARD) != 0.0 || now < (datetime)g_state.Get(SK_PAUSE)) g_state.Set("s_close", 1);
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   g_peak = MathMax(g_peak, eq); g_drawdown = MathMax(g_drawdown, g_peak - eq);
  }

void CancelOrder(string why)
  {
   if(g_order == 0 || TimeCurrent() < g_retry) return;
   // Lệnh có thể vừa tự hết hạn trên sàn, trước khi sự kiện xóa tới EA.
   if(!OrderSelect(g_order)) { g_needSync = true; return; }
   g_retry = TimeCurrent() + 5;
   if(ResultOk(g_trade.OrderDelete(g_order)))
     { g_cancelled++; Note("huy", why); g_needSync = true; }
  }
void ClosePosition(string why)
  {
   g_state.Set("s_close", 1); // lưu ý định trước gửi, lần sau/khởi động lại vẫn tiếp tục đóng
   if(g_position == 0 || TimeCurrent() < g_retry) return;
   g_retry = TimeCurrent() + 5;
   if(ResultOk(g_trade.PositionClose(g_position))) { Note("dong", why); g_needSync = true; }
  }

void Manage(const MqlTick &t, bool newBar, bool hitOpposite)
  {
   if(g_order != 0)
     {
      int dir = (int)g_state.Get("s_dir");
      double sl = g_state.Get("s_sl"), tp = g_state.Get("s_tp");
      bool expired = t.time >= (datetime)g_state.Get("s_exp");
      bool invalid = dir > 0 ? t.bid <= sl || t.bid >= tp : t.ask >= sl || t.ask <= tp;
       bool dead = !g_havePlan || !ScalpBiasAllowed(dir, g_ctx.htf.T[1].st.trend)
                   || !g_ctx.Alive(g_signal.htf, g_signal.zoneId, g_signal.zoneType, dir, g_signal.top, g_signal.bottom);
      if(!InpEnabled || Blocked(t.time) || expired || invalid || dead)
         CancelOrder(expired ? "Lệnh chờ hết hạn đã chọn" : "Lệnh chờ hết điều kiện/tắt bot");
     }
   if(g_position == 0 || !PositionSelectByTicket(g_position)) return;
   datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
   int toEnd, fromStart;
   bool nearBreak = SessionInfo(_Symbol, t.time, toEnd, fromStart) && toEnd <= 1;
   if(g_state.Get("s_close") != 0.0 || t.time - opened >= InpMaxMinutes * 60 || nearBreak)
     { ClosePosition("Giới hạn/thời gian giữ/kế hoạch khớp không đạt"); return; }
   if(!InpManage || g_ctx.bars.n < 1 || g_state.Get("s_uncert") != 0.0) return;
   double fill = PositionGetDouble(POSITION_PRICE_OPEN), oldSl = PositionGetDouble(POSITION_SL), tp = PositionGetDouble(POSITION_TP);
   double exitPrice = g_dir > 0 ? t.bid : t.ask, spread = t.ask - t.bid, risk = g_state.Get("s_risk");
   double gain = g_dir * (exitPrice - fill), minDist = MinDistance();
   SmcBar b = g_ctx.bars.b[g_ctx.bars.n - 1];
   // Chỉ nến sau lúc khớp mới được dùng để siết/đóng sớm; không lấy nến tín hiệu làm bằng chứng sau khớp.
   if(newBar && b.t >= opened && g_ctx.bars.n >= 2)
     {
      SmcBar previous = g_ctx.bars.b[g_ctx.bars.n - 2];
      // Không lấy thân/râu của nến trước lúc vào làm bằng chứng đảo chiều sau khớp.
      if(ScalpStrongReverse(g_dir, previous, b, hitOpposite, g_state.Get("s_guard"), previous.t >= opened))
        { g_earlyExit++; ClosePosition("M1 đảo mạnh/phá mốc bảo vệ: rút lệnh"); return; }
     }
   double nextSl = oldSl;
   if(risk > 0.0 && gain >= MathMax(0.5 * risk, 2.0 * spread + 2.0 * InpSlip)
      && ScalpTightens(g_dir, oldSl, Price(fill), exitPrice, minDist))
      nextSl = Price(fill);
   if(newBar && b.t >= opened)
     {
       double swing = ScalpMicroSwing(g_ctx.bars, g_dir, opened);
       double guard = g_state.Get("s_guard");
       if(swing > 0.0 && (guard <= 0.0 || g_dir * (swing - guard) > 0.0))
          g_state.Set("s_guard", swing);
       if(swing > 0.0)
         {
          double candidate = Price(swing - g_dir * MathMax(spread, 0.1 * b.atr) + (g_dir < 0 ? spread : 0.0));
          if(ScalpTightens(g_dir, nextSl, candidate, exitPrice, minDist)) nextSl = candidate;
         }
     }
   if(nextSl != oldSl && t.time >= g_retry)
     {
      g_retry = t.time + 2;
      // CTrade cần ticket; giữ nguyên TP, không dùng CExec.ModifySL cũ (nó xóa TP).
      if(ResultOk(g_trade.PositionModify(g_position, nextSl, tp)))
        {
          if(g_dir * (oldSl - fill) < 0.0 && g_dir * (nextSl - fill) >= 0.0)
            { g_be++; g_state.Set("s_be", 1); }
          else g_trailing++;
         Note("doi_dung", "Dừng mới " + DoubleToString(nextSl, _Digits) + "; giữ chốt " + DoubleToString(tp, _Digits));
        }
     }
  }

void Reject(const ScalpSignal &s, string why)
  {
   // Vào sớm được xét mỗi giây; chỉ ghi một lần mỗi nến + lý do để tránh lặp nhật ký.
   if(g_rejectBar == s.bar && g_last == why) return;
   g_rejectBar = s.bar; g_rejected++; Note("bo", why);
  }
void TrySignal(const ScalpSignal &s, const MqlTick &t)
  {
   if(!s.valid || s.bar <= g_attempt || s.touch < g_flatSince || g_position != 0 || g_order != 0) return;
   if(!InpEnabled || Blocked(t.time)) return;
   if(!g_tester && (!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !TerminalInfoInteger(TERMINAL_CONNECTED))) return;
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED) || !AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) || !AccountInfoInteger(ACCOUNT_TRADE_EXPERT)) return;
   long mode = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   if(mode != SYMBOL_TRADE_MODE_FULL && !(s.dir > 0 && mode == SYMBOL_TRADE_MODE_LONGONLY) && !(s.dir < 0 && mode == SYMBOL_TRADE_MODE_SHORTONLY)) return;
   int toEnd, fromStart;
   if(!SessionInfo(_Symbol, t.time, toEnd, fromStart)) { Reject(s, "Sàn đang nghỉ"); return; }
   if(toEnd <= InpMaxMinutes + InpPendingMinutes) { Reject(s, "Gần giờ nghỉ: không giữ lệnh qua phiên"); return; }
   for(int k = 0; k < HTF_COUNT; k++)
      if(g_ctx.htf.T[k].B.n < 30 || g_ctx.htf.T[k].lastOpen < iTime(_Symbol, g_ctx.htf.T[k].tf, 1))
        { Reject(s, "Dữ liệu khung lớn chưa cập nhật đủ"); return; }
   ScalpPlan p; string why;
   if(!g_ctx.Plan(s, t, InpEntry, InpSlip, InpMinRatio, p, why)) { Reject(s, why); return; }
   p.entry = Price(p.entry); p.sl = Price(p.sl); p.tp = Price(p.tp);
   p.ratio = ScalpNetRatio(s.dir, p.entry, p.sl, p.tp, InpSlip);
   double exitNow = s.dir > 0 ? t.bid : t.ask, d = MinDistance();
   if(p.ratio < InpMinRatio || s.dir * (p.entry - p.sl) > SCALP_MAX_RISK_ATR * s.atr + g_tickSize
      || s.dir * (p.entry - p.sl) <= d || s.dir * (p.tp - p.entry) <= d
      || s.dir * (exitNow - p.sl) <= d || s.dir * (p.tp - exitNow) <= d)
     { Reject(s, "Mốc dừng/chốt không còn hợp lệ sau làm tròn hoặc giá đã đi quá xa"); return; }
   if(p.limit && s.dir * ((s.dir > 0 ? t.ask : t.bid) - p.entry) <= d) { Reject(s, "Lệnh chờ quá gần giá"); return; }
   double riskMoney = g_money.TradeRisk(s.dir, SCALP_LOT, p.entry, p.sl, 2.0 * InpSlip);
   if(riskMoney > InpRiskPct / 100.0 * g_money.equity) { Reject(s, "Rủi ro vượt ngân sách mỗi lệnh"); return; }
   if(!g_money.MarginOk(s.dir, SCALP_LOT, p.entry, g_settings, why)) { Reject(s, why); return; }
   if(s.known > t.time || p.targetKnown > t.time) { g_checks++; Reject(s, "Sai thời điểm biết vùng"); return; }
   datetime expires = g_bar + InpPendingMinutes * 60;
   datetime brokerExpires = g_bar + 3 * 60; // Hạn 1 phút bị từ chối; EA hủy sớm, sàn giữ hạn dự phòng đã dùng được.
   if(p.limit && (SymbolInfoInteger(_Symbol, SYMBOL_EXPIRATION_MODE) & SYMBOL_EXPIRATION_SPECIFIED) == 0)
     { Reject(s, "Sàn không hỗ trợ lệnh chờ có hạn giờ"); return; }
   g_signals++;
   g_attempt = s.bar; g_state.Set("s_tried", (double)g_attempt);
   g_state.Del("s_pos"); SavePlan(s, p, expires);
   // Không gửi lại lệnh mở khi chưa chắc máy chủ nhận hay chưa. Lưu khóa trước khi gọi mạng.
   g_state.Set("s_uncert", 1); g_state.Set("s_wait", 1); g_state.Set("s_ack", 0); g_state.Flush();
   string comment = s.early ? "Scalp wick" : (p.limit ? "Scalp limit" : "Scalp closed");
   bool ok;
   if(p.limit)
      ok = s.dir > 0 ? g_trade.BuyLimit(SCALP_LOT, p.entry, _Symbol, p.sl, p.tp, ORDER_TIME_SPECIFIED, brokerExpires, comment)
                     : g_trade.SellLimit(SCALP_LOT, p.entry, _Symbol, p.sl, p.tp, ORDER_TIME_SPECIFIED, brokerExpires, comment);
   else
      ok = s.dir > 0 ? g_trade.Buy(SCALP_LOT, _Symbol, 0.0, p.sl, p.tp, comment)
                     : g_trade.Sell(SCALP_LOT, _Symbol, 0.0, p.sl, p.tp, comment);
   uint rc = g_trade.ResultRetcode();
   bool accepted = ResultOk(ok);
   if(accepted) g_state.Set("s_ack", (double)g_trade.ResultOrder());
   else if(rc != TRADE_RETCODE_TIMEOUT && rc != TRADE_RETCODE_CONNECTION) g_state.Set("s_wait", 0);
   if(accepted || (rc != TRADE_RETCODE_TIMEOUT && rc != TRADE_RETCODE_CONNECTION)) g_state.Set("s_uncert", 0);
   if(accepted)
     {
      g_sent++;
      g_ctx.Used(s);
       Note("ke_hoach", StringFormat("%s %s; vao %s; dung %s; chot %s (%s); ty le %.3f; RSI %.2f; hoat dong %.2f; som %d; vung M1 #%d; cham %s; biet %s; H1 %d H4 %d D1 %d; ATR %.6f; loai %s; phanung R%d; trong_vung_lon %d",
          s.dir > 0 ? "MUA" : "BAN", p.limit ? "cho hoi" : "thi truong", DoubleToString(p.entry, _Digits),
          DoubleToString(p.sl, _Digits), DoubleToString(p.tp, _Digits), p.targetName, p.ratio, s.rsi, s.activity, (int)s.early,
          s.zoneId, TimeToString(s.touch, TIME_DATE | TIME_SECONDS), TimeToString(s.known, TIME_DATE | TIME_SECONDS),
          s.biasH1, s.biasH4, s.biasD1, s.atr, HtfTypeName[s.zoneType], s.reaction + 1, p.contextInside));
     }
   g_needSync = true; Sync(); g_state.Flush();
  }

bool Warm()
  {
   MqlRates r[]; ArraySetAsSeries(r, false);
   int got = CopyRates(_Symbol, _Period, 1, 1000, r);
   if(got < 1000 || !SeriesInfoInteger(_Symbol, _Period, SERIES_SYNCHRONIZED)) return false;
   // Lần gọi lại sau dữ liệu chưa sẵn phải bắt đầu sạch, không cộng lại lịch sử.
   g_ctx.Init();
   g_ctx.htf.Warm(r[0].time, r[0].open);
   ScalpSignal discard;
   for(int i = 0; i < got; i++)
     {
      g_ctx.Add(r[i], discard);
      datetime next = i + 1 < got ? r[i + 1].time : iTime(_Symbol, _Period, 0);
      g_ctx.htf.Sync(next, g_ctx.bars, false);
      g_ctx.htf.ArmCheck(i + 1 < got ? r[i + 1].open : iOpen(_Symbol, _Period, 0), next);
      g_ctx.ConfirmBias(discard);
     }
   g_bar = iTime(_Symbol, _Period, 0); g_lastClosed = r[got - 1].time;
   return g_ctx.force.Ready();
  }

bool Ready()
  {
   if(AccountInfoDouble(ACCOUNT_EQUITY) <= 0.0 || (!g_tester && !TerminalInfoInteger(TERMINAL_CONNECTED))) return false;
   if(!g_tester && AccountInfoInteger(ACCOUNT_TRADE_MODE) != ACCOUNT_TRADE_MODE_DEMO)
     { g_last = "Chỉ chạy demo"; ExpertRemove(); return false; }
   if(AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
     { g_last = "Cần tài khoản giữ lệnh riêng (hedging)"; ExpertRemove(); return false; }
   if(!Warm()) return false;
   g_tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(g_tickSize <= 0.0 || step <= 0.0) return false;
   if(SCALP_LOT < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN) - 1e-9 || MathAbs(SCALP_LOT / step - MathRound(SCALP_LOT / step)) > 1e-6)
     { g_last = "Sàn không cho khối lượng 0,01"; ExpertRemove(); return false; }
   if(!g_state.Init(_Symbol, InpMagic) || !AcquireLock()) { g_last = "Đã có bản bot khác trên ký hiệu này"; ExpertRemove(); return false; }
   g_login = AccountInfoInteger(ACCOUNT_LOGIN); g_server = AccountInfoString(ACCOUNT_SERVER);
   if(g_tester) GlobalVariablesDeleteAll(g_state.Prefix());
   g_attempt = (datetime)g_state.Get("s_tried");
   // Sau restart bỏ cả cửa sổ k0/k0+1: dấu vùng Used chỉ có trong RAM.
   if(!g_tester) g_attempt = MathMax(g_attempt, g_bar + PeriodSeconds(_Period));
   g_money.Init(_Symbol, InpMagic, SCALP_VN, GetPointer(g_state));
   g_money.Update(TimeCurrent());
   g_trade.SetExpertMagicNumber(InpMagic); g_trade.SetAsyncMode(false); g_trade.SetTypeFillingBySymbol(_Symbol);
   g_trade.SetDeviationInPoints(10); g_trade.LogLevel(LOG_LEVEL_ERRORS);
   g_started = TimeCurrent(); g_peak = AccountInfoDouble(ACCOUNT_EQUITY);
   g_flatSince = g_started; g_ctx.rearmed = g_ctx.biasBlocked = 0;
   g_startBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_report.Init("BotScalpPhanUng\\" + (g_tester ? InpRunName : "demo_" + (string)TimeCurrent()) + "_" + _Symbol + "_" + StringSubstr(EnumToString(_Period), 7) + "\\", InpExportCandles);
   g_ready = true; Sync();
   // Sau restart, mọi lệnh chờ cũ bị hủy vì không tái dựng lại hình dạng tín hiệu đang chạy.
   if(g_order != 0) CancelOrder("Khởi động lại: hủy lệnh chờ cũ");
   Note("khoi_dong", InpEnabled ? "Bot bật; chờ phản ứng theo §26" : "Bot tắt; chỉ quản lý lệnh đã có");
   return true;
  }

int OnInit()
  {
   g_tester = MQLInfoInteger(MQL_TESTER) != 0;
   g_log.Init(false, SCALP_VN, "BotScalpPhanUng");
   if(!g_tester && InpPendingMinutes != 3)
     { Print("[BotScalpPhanUng] Hạn chờ ngắn chỉ dùng trong máy thử; bản mặc định giữ 3 phút"); return INIT_PARAMETERS_INCORRECT; }
   if(_Symbol != "XAUUSDm" || _Period != PERIOD_M1
      || InpMinRatio <= 0.0 || InpSlip < 0.0 || InpRiskPct <= 0.0 || InpMaxMinutes < 1 || InpMaxMinutes > 10
      || InpPendingMinutes < 1 || InpPendingMinutes > 3
      || InpMagic <= 0 || InpDayLoss <= 0.0 || InpWeekLoss <= 0.0 || InpTotalLoss <= 0.0
      || StringFind(InpRunName, "\\") >= 0 || StringFind(InpRunName, "/") >= 0 || StringFind(InpRunName, "..") >= 0)
      return INIT_PARAMETERS_INCORRECT;
   ZeroMemory(g_settings);
   g_settings.magic = InpMagic; g_settings.lot = SCALP_LOT; g_settings.limitUnit = LIMIT_PERCENT;
   g_settings.dayLoss = InpDayLoss; g_settings.weekLoss = InpWeekLoss; g_settings.totalLoss = InpTotalLoss;
   g_settings.minFreeMarginPct = 50.0; g_settings.minMarginLevel = 500.0;
   g_ctx.Init();
   if(!g_tester) EventSetTimer(1);
   return INIT_SUCCEEDED;
  }

void OnTick()
  {
   if(!g_ready && !Ready()) return;
   if(!g_tester && (AccountInfoInteger(ACCOUNT_LOGIN) != g_login || AccountInfoString(ACCOUNT_SERVER) != g_server
                   || AccountInfoInteger(ACCOUNT_TRADE_MODE) != ACCOUNT_TRADE_MODE_DEMO))
     { Note("loi", "Tài khoản đã đổi: dừng EA, không gửi lệnh sang tài khoản khác"); ExpertRemove(); return; }
   MqlTick t; if(!SymbolInfoTick(_Symbol, t)) return;
   // Khi rảnh, tín hiệu chỉ xét mỗi giây/nến mới. Các tick còn lại trong cùng giây không tạo quyết định.
   // Đang có lệnh hoặc sự kiện sàn thì vẫn kiểm tra ngay để giữ nguyên bảo vệ rủi ro.
   if(t.time == g_second && g_position == 0 && g_order == 0 && !g_needSync) return;
   datetime current = iTime(_Symbol, _Period, 0);
   bool gap = g_disconnected || ScalpGap(g_previousTick, t.time, PeriodSeconds(_Period));
   if(gap) g_gapBar = current;
   g_disconnected = false;
   g_previousTick = t.time;
   if(g_needSync) Sync();
   if(g_state.Get("s_wait") != 0.0 && t.time != g_second) Sync();
   CheckMoney(t.time);
   bool second = t.time != g_second;
   bool newBar = current > g_bar, opposite = false;
   ScalpSignal s; ZeroMemory(s);
   if(newBar)
     {
      MqlRates r[]; ArraySetAsSeries(r, false);
      int got = CopyRates(_Symbol, _Period, g_lastClosed + 1, current - 1, r);
      if(got > 0 && r[got - 1].time == iTime(_Symbol, _Period, 1))
        {
         for(int k = 0; k < got; k++)
           {
            opposite = g_position != 0 && g_ctx.HitsOpposite(g_dir, r[k]);
            g_ctx.Add(r[k], s, g_position == 0 && g_order == 0 && !Blocked(t.time) && r[k].time >= g_flatSince);
            datetime next = k + 1 < got ? r[k + 1].time : current;
            g_ctx.htf.Sync(next, g_ctx.bars, k == got - 1);
            g_ctx.htf.ArmCheck(k + 1 < got ? r[k + 1].open : iOpen(_Symbol, _Period, 0), next);
            g_ctx.ConfirmBias(s);
            g_report.Candle(r[k], g_ctx.bars.b[g_ctx.bars.n - 1].atr, g_ctx.force.rsi, g_ctx.force.activity,
                            g_ctx.htf.T[1].st.trend, g_ctx.htf.T[2].st.trend, g_ctx.htf.T[3].st.trend, t.time);
           }
         g_lastClosed = r[got - 1].time; g_bar = current;
         if(got != 1 || t.time - current > 5 || gap) s.valid = false; // không vào muộn sau mất mạng/nạp thiếu
        }
      else newBar = false;
     }
   if(second || newBar || g_state.Get("s_close") != 0.0) Manage(t, newBar, opposite);
   if(g_needSync) Sync();
   if(newBar) TrySignal(s, t);
   if(second && InpEntry == SCALP_AUTO && InpEarlyWick && current == g_bar && current != g_gapBar
      && g_position == 0 && g_order == 0 && current > g_attempt)
     {
      MqlRates r[];
      if(CopyRates(_Symbol, _Period, 0, 1, r) == 1 && r[0].time == current && g_ctx.Early(r[0], t, s)) TrySignal(s, t);
     }
   if(second)
     {
      g_second = t.time;
      int day = YmdKey(VnDayStart(t.time, SCALP_VN), SCALP_VN);
      if(day != g_day) { g_day = day; g_days++; }
      if(!g_tester || MQLInfoInteger(MQL_VISUAL_MODE))
         Comment("BotScalpPhanUng · ", EnumToString(_Period), " · ", InpEnabled ? "BẬT" : "TẮT", "\n",
                 "Đang mở: ", g_position != 0 ? 1 : 0, " · Chờ hồi: ", g_order != 0 ? 1 : 0, "\n",
                 "Hướng H1: ", g_ctx.htf.T[1].st.trend > 0 ? "Ưu tiên mua" : (g_ctx.htf.T[1].st.trend < 0 ? "Ưu tiên bán" : "Chưa rõ"),
                 " · Vùng M1 · Giữ tối đa ", InpMaxMinutes, " phút\n",
                 "Lời/lỗ ngày: ", DoubleToString(g_money.dayPnl, 2), " · ", g_last);
      g_state.Flush();
     }
  }

void OnTimer()
  {
   if(!TerminalInfoInteger(TERMINAL_CONNECTED)) g_disconnected = true;
  }

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  {
   if(!g_ready) return;
   if(AccountInfoInteger(ACCOUNT_LOGIN) != g_login || AccountInfoString(ACCOUNT_SERVER) != g_server) return;
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD || trans.type == TRADE_TRANSACTION_ORDER_DELETE || trans.type == TRADE_TRANSACTION_ORDER_ADD)
      g_needSync = true;
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD && HistoryDealSelect(trans.deal)
      && (HistoryDealGetInteger(trans.deal, DEAL_TYPE) == DEAL_TYPE_BALANCE || HistoryDealGetInteger(trans.deal, DEAL_TYPE) == DEAL_TYPE_CREDIT))
      g_money.OnBalance(HistoryDealGetDouble(trans.deal, DEAL_PROFIT));
  }

double OnTester()
  {
   if(!g_ready) return 0.0;
   int checks = g_checks + g_ctx.htf.useEarly + g_ctx.htf.ingestEarly + g_ctx.htf.late;
   string settings = StringFormat("rules=3 mode=%d early=%d manage=%d min_ratio=%.2f slip=%.2f max_minutes=%d risk_pct=%.2f lot=%.2f day_loss=%.2f week_loss=%.2f total_loss=%.2f max_risk_atr=%.1f rearmed=%d bias_blocks=%d pending_minutes=%d",
      (int)InpEntry, (int)InpEarlyWick, (int)InpManage, InpMinRatio, InpSlip, InpMaxMinutes, InpRiskPct, SCALP_LOT, InpDayLoss, InpWeekLoss, InpTotalLoss,
      SCALP_MAX_RISK_ATR, g_ctx.rearmed, g_ctx.biasBlocked, InpPendingMinutes);
   return g_report.Finish(InpMagic, g_started, InpSlip, g_drawdown, g_be, g_trailing, g_earlyExit,
                          g_signals, g_rejected, g_sent, g_cancelled, g_errors, checks, g_days, g_startBalance, settings);
  }
void OnDeinit(const int reason)
  {
   EventKillTimer();
   g_report.Close();
   if(g_ready) g_state.Flush();
   if(g_lockOwned && GlobalVariableGet(g_lock) == (double)ChartID()) GlobalVariableDel(g_lock);
   Comment("");
  }
