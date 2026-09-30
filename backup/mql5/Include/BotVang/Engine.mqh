// Bộ máy của bot BotVang: vào lệnh theo tín hiệu đã đo ở Lab, chạy lệnh (thang bậc, khóa lời tại cản,
// siết trước tin), đảo chiều (mặc định tắt), đóng theo giờ, giới hạn lỗ, đo trượt giá, phanh, khôi phục sau khởi động lại.
#ifndef BOTVANG_ENGINE_MQH
#define BOTVANG_ENGINE_MQH

#include "Types.mqh"
#include "Zones.mqh"
#include "Bias.mqh"
#include "Filters.mqh"
#include "Signal.mqh"
#include "State.mqh"
#include "Exec.mqh"
#include "Stats.mqh"
#include "Journal.mqh"

// Mã lý do NGHỈ (lưu trong State)
#define PW_NONE        0
#define PW_BRAKE       1
#define PW_DAY         2
#define PW_WEEK        3
#define PW_SLIP        4
#define PW_PROFIT_DAY  5
#define PW_PROFIT_WEEK 6

#define TAG_OPEN "BotVang"
#define TAG_FLIP "BotVang dao"

class CEngine
  {
private:
   string            m_sym;
   CJournal         *m_log;
   int               m_hAtrM5;
   datetime          m_lastBar;
   datetime          m_lastH1;
   bool              m_reconciled;                 // đã đối chiếu lệnh với sàn (chỉ làm khi terminal đã kết nối)
   datetime          m_orphanSince;                // lệnh chờ đảo còn lại mà không còn lệnh gốc: từ lúc nào
   datetime          m_goneSince;                  // lệnh đã mất trên sàn mà dữ liệu lệnh chưa được dọn: từ lúc nào
   long              m_seenPosId;                  // lệnh gần nhất đã tính cản đối diện
   double            m_oppLo, m_oppHi, m_oppEdge;   // cản mạnh đối diện của lệnh đang chạy
   bool              m_newsTightened;
   bool              m_needSlReset;
   ulong             m_sendMsc;                    // lúc gửi yêu cầu mở (để đo độ trễ)
   double            m_closeWant;                  // giá mong muốn lúc gửi đóng lệnh (0 = không do bot gửi)
   ulong             m_closeSent[];                // lệnh/lệnh chờ đã gửi đóng/hủy ở trạng thái ĐANG ĐÓNG
   datetime          m_closeSentAt[];
   int               m_slipDay;
   double            m_flipFailPrice;              // lệnh chờ đảo bị sàn từ chối hẳn: không gửi lại cùng giá trong cùng nến
   datetime          m_flipFailBar;

   static string     PauseText(int w)
     {
      switch(w)
        {
         case PW_BRAKE:       return "Thua liên tiếp: nghỉ";
         case PW_DAY:         return "Chạm giới hạn lỗ ngày";
         case PW_WEEK:        return "Chạm giới hạn lỗ tuần";
         case PW_SLIP:        return "Vừa bị trượt giá mạnh";
         case PW_PROFIT_DAY:  return "Đạt mục tiêu lời ngày";
         case PW_PROFIT_WEEK: return "Đạt mục tiêu lời tuần";
        }
      return "";
     }

   static bool       LimitPause(int w) { return w == PW_DAY || w == PW_WEEK || w == PW_PROFIT_DAY || w == PW_PROFIT_WEEK; }

   double            AtrM5(void)
     {
      double b[];
      return CopyBuffer(m_hAtrM5, 0, 1, 1, b) == 1 ? b[0] : 0.0;
     }

   double            StepNow(const MqlTick &t)
     {
      bool bySpread;
      return StepB(AtrM5(), t.ask - t.bid, s.stepAtrMult, s.stepMinSpreadMult, SymbolInfoDouble(m_sym, SYMBOL_TRADE_TICK_SIZE), _Digits, bySpread);
     }

   // NGHỈ tới lúc until; không bao giờ rút ngắn một lần NGHỈ dài hơn đang có
   void              Pause(datetime until, int why)
     {
      if(until <= pauseUntil)
         return;
      pauseUntil = until;
      pauseWhy = why;
      st.Set(SK_PAUSE, (double)until);
      st.Set(SK_PAUSE_WHY, why);
      m_log.Add("nghi", PauseText(why) + " tới " + TimeToString(until + mc.vnOffset * 3600, TIME_DATE | TIME_MINUTES) + " (giờ VN)");
     }

   // Cản mạnh đối diện theo chiều lệnh, tính ngay lúc có lệnh mới (như Lab) và cập nhật mỗi nến
   void              RecalcOpp(int dir, double bid)
     {
      double dist;
      int j = zones.NearestStrong(dir, bid, s.strongScore, dist);
      m_oppEdge = j >= 0 ? (dir > 0 ? zones.zones[j].lo : zones.zones[j].hi) : 0.0;
      m_oppLo = j >= 0 ? zones.zones[j].lo : 0.0;
      m_oppHi = j >= 0 ? zones.zones[j].hi : 0.0;
     }

   // Đọc lệnh và lệnh chờ của bot trên sàn; xử lý lệnh thừa
   void              Sync(const MqlTick &t)
     {
      ulong pos[], ord[];
      int np = ex.Positions(pos), no = ex.Orders(ord);
      long want = (long)st.Get(SK_POS, 0);
      hasPos = false;
      posCount = np;
      int keep = -1;
      for(int i = 0; i < np; i++)
         if(PositionSelectByTicket(pos[i]) && PositionGetInteger(POSITION_IDENTIFIER) == want)
            keep = i;
      if(np == 1 && keep < 0 && !recovery && !closing)
        {
         // lệnh mới chưa ghi nhận (giao dịch đang được xử lý): chờ OnTradeTransaction; quá 10 giây (lệnh bot vừa gửi: 30 giây)
         // mà vẫn chưa ghi nhận thì khóa an toàn
         int waitSec = (long)st.Get(SK_REQ_KIND, 0) != 0 ? 30 : 10;
         if(!ex.Busy(RQ_OPEN) && PositionSelectByTicket(pos[0]) && TimeCurrent() - (datetime)PositionGetInteger(POSITION_TIME) > waitSec)
            EnterRecovery("Có lệnh của bot mà bot không ghi nhận");
        }
      if(np > 1 && !closing)
        {
         if(keep < 0)
            EnterRecovery("Có " + (string)np + " lệnh của bot, không xác định được lệnh nào cũ");
         else
            for(int i = 0; i < np; i++)
               if(i != keep && PositionSelectByTicket(pos[i]) && !ex.Busy(RQ_CLOSE))
                 {
                  int d = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 1 : -1;
                  m_log.Add("lenh_thua", "Có lệnh thừa #" + (string)pos[i] + ": đóng");
                  m_closeWant = d > 0 ? t.bid : t.ask;
                  ex.Close(pos[i], d, PositionGetDouble(POSITION_VOLUME));
                 }
        }
      if(keep >= 0 && PositionSelectByTicket(pos[keep]))
        {
         hasPos = true;
         posTicket = pos[keep];
         posDir = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 1 : -1;
         posOpen = PositionGetDouble(POSITION_PRICE_OPEN);
         posSl = PositionGetDouble(POSITION_SL);
         posVol = PositionGetDouble(POSITION_VOLUME);
         posProfit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
         posB = st.Get(SK_POS_B, 0.0);
         if(posSl > 0.0)
           {
            st.Set(SK_WANT_SL, posSl);
            st.Set(SK_WANT_SL_ID, (double)want);
           }
         if(want != m_seenPosId)
           {
            m_seenPosId = want;
            RecalcOpp(posDir, t.bid);
            barsInOpp = 0;
           }
        }
      // Lệnh chờ: chỉ một lệnh chờ đảo (ghi chú TAG_FLIP) là hợp lệ; lệnh chờ khác của bot thì hủy.
      // KHÔI PHỤC hoặc DỪNG HẲN: gỡ luôn lệnh chờ đảo để không tự đảo chiều.
      hasFlip = false;
      for(int i = 0; i < no; i++)
        {
         if(!hasFlip && OrderSelect(ord[i]) && OrderGetString(ORDER_COMMENT) == TAG_FLIP)
           {
            hasFlip = true;
            flipTicket = ord[i];
            flipPrice = OrderGetDouble(ORDER_PRICE_OPEN);
            st.Set(SK_FLIP, (double)ord[i]);
            if((recovery || hardStop) && !closing && !ex.Busy(RQ_FLIP_DEL))
              {
               m_log.Add("huy_dao", "Gỡ lệnh chờ đảo vì " + (recovery ? "đang khôi phục" : "đang dừng hẳn"));
               ex.Delete(ord[i]);
              }
            continue;
           }
         if(!closing && !ex.Busy(RQ_FLIP_DEL) && !ex.Busy(RQ_FLIP_PLACE))
           {
            m_log.Add("lenh_cho_thua", "Có lệnh chờ không thuộc bot quản lý #" + (string)ord[i] + ": hủy");
            ex.Delete(ord[i]);
           }
        }
      ordersCount = no;
      // KHÔI PHỤC mà không còn lệnh và lệnh chờ nào: tự về CHỜ
      if(recovery && np == 0 && no == 0)
        {
         recovery = false;
         st.ClearTrade();
         m_log.Add("het_khoi_phuc", "Lệnh cần xác nhận đã không còn trên sàn: bot về CHỜ");
         return;
        }
      // Không còn lệnh: lệnh chờ đảo còn lại mà không còn lệnh gốc quá 10 giây thì hủy; dữ liệu lệnh cũ để
      // OnTradeTransaction dọn (đo trượt giá), quá 10 giây mà chưa ai dọn thì tự dọn
      if(np == 0)
        {
         if(want == 0)
            m_goneSince = 0;   // dữ liệu lệnh cũ đã được OnTradeTransaction dọn
         if(hasFlip)
           {
            if(m_orphanSince == 0)
               m_orphanSince = TimeCurrent();
            else
               if(TimeCurrent() - m_orphanSince > 10 && !ex.Busy(RQ_FLIP_DEL))
                 {
                  m_log.Add("don_lenh_cho", "Xóa lệnh chờ đảo không còn lệnh gốc");
                  ex.Delete(flipTicket);
                 }
           }
         else
            m_orphanSince = 0;
         if(!hasFlip && want != 0 && !ex.Busy(RQ_OPEN))
           {
            if(m_goneSince == 0)
               m_goneSince = TimeCurrent();
            else
               if(TimeCurrent() - m_goneSince > 10)
                 {
                  st.ClearTrade();
                  m_goneSince = 0;
                 }
           }
        }
      else
        {
         m_orphanSince = 0;
         m_goneSince = 0;
        }
     }

   void              EnterRecovery(const string why)
     {
      if(recovery)
         return;
      recovery = true;
      recoveryInfo = why;
      MqlTick t;
      SymbolInfoTick(m_sym, t);
      // B đề xuất: B đã lưu nếu lệnh là lệnh bot vừa gửi (SK_REQ_KIND = 1); không thì tính theo ATR hiện tại
      recoveryB = (long)st.Get(SK_REQ_KIND, 0) == 1 && st.Get(SK_POS_B, 0.0) > 0.0 ? st.Get(SK_POS_B, 0.0) : StepNow(t);
      m_log.Add("khoi_phuc", why + ": khóa an toàn, chờ bạn xác nhận trên bảng");
     }

   // Kiểm tra giới hạn lỗ/lời. Giới hạn đang áp mà còn lệnh (ví dụ sau khởi động lại) thì đóng tiếp.
   void              CheckLimits(datetime now)
     {
      bool active = hardStop || (now < pauseUntil && LimitPause(pauseWhy));
      if(active && !closing && (posCount > 0 || ordersCount > 0))
         StartClosing(hardStop ? "Đang dừng hẳn (giới hạn lỗ tổng)" : PauseText(pauseWhy));
      int hit = money.LimitHit(s);
      if(hit == 0)
         return;
      if(hit == 3)
        {
         if(!hardStop)
           {
            hardStop = true;
            st.Set(SK_HARD, 1);
            m_log.Add("dung_han", "Chạm giới hạn lỗ tổng " + DoubleToString(money.totalPnl, 2) + ": đóng hết, dừng hẳn tới khi bạn bấm cho chạy lại");
            StartClosing("Chạm giới hạn lỗ tổng");
           }
         return;
        }
      if(now < pauseUntil && LimitPause(pauseWhy))
         return;
      datetime nextDay = VnDayStart(now, mc.vnOffset) + 86400;
      datetime nextWeek = VnWeekStart(now, mc.vnOffset) + 7 * 86400;
      int why = hit == 1 ? PW_DAY : (hit == 2 ? PW_WEEK : (hit == 4 ? PW_PROFIT_DAY : PW_PROFIT_WEEK));
      Pause(hit == 1 || hit == 4 ? nextDay : nextWeek, why);
      StartClosing(PauseText(why));
     }

   // Tới giờ đóng: hết khung giờ chạy, <= 30 phút tới giờ nghỉ của sàn, hoặc sàn đang nghỉ
   bool              MustCloseByTime(datetime now)
     {
      if(timeOn && !InTimeWindow(now, mc.vnOffset, mc.startMin, mc.endMin))
         return true;
      int toEnd, fromStart;
      if(!SessionAt(mc, m_sym, now, toEnd, fromStart))
         return true;
      return toEnd <= mc.breakCloseMin;
     }

   void              StartClosing(const string why)
     {
      if(closing)
         return;
      closing = true;
      closingWhy = why;
      st.Set(SK_CLOSING, 1);
      ArrayResize(m_closeSent, 0);
      ArrayResize(m_closeSentAt, 0);
      m_log.Add("dang_dong", why + ": đóng/hủy mọi lệnh của bot");
     }

   // ĐANG ĐÓNG: gửi đóng/hủy một lần cho mỗi lệnh; gửi lại sau 10 giây nếu vẫn còn; thoát khi không còn gì
   void              DoClosing(void)
     {
      ulong pos[], ord[];
      int np = ex.Positions(pos), no = ex.Orders(ord);
      if(np == 0 && no == 0)
        {
         closing = false;
         st.Set(SK_CLOSING, 0);
         recovery = false;
         m_log.Add("da_dong_het", "Sàn xác nhận không còn lệnh/lệnh chờ nào của bot");
         return;
        }
      for(int i = 0; i < no; i++)
         if(!ex.Busy(RQ_FLIP_DEL) && DueToSend(ord[i]))
            ex.Delete(ord[i]);
      for(int i = 0; i < np; i++)
         if(!ex.Busy(RQ_CLOSE) && PositionSelectByTicket(pos[i]) && DueToSend(pos[i]))
           {
            int dir = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 1 : -1;
            m_closeWant = dir > 0 ? SymbolInfoDouble(m_sym, SYMBOL_BID) : SymbolInfoDouble(m_sym, SYMBOL_ASK);
            ex.Close(pos[i], dir, PositionGetDouble(POSITION_VOLUME));
           }
     }

   bool              DueToSend(ulong ticket)
     {
      for(int i = 0; i < ArraySize(m_closeSent); i++)
         if(m_closeSent[i] == ticket)
           {
            if(TimeCurrent() - m_closeSentAt[i] < 10)
               return false;
            m_closeSentAt[i] = TimeCurrent();
            return true;
           }
      int n = ArraySize(m_closeSent);
      ArrayResize(m_closeSent, n + 1);
      ArrayResize(m_closeSentAt, n + 1);
      m_closeSent[n] = ticket;
      m_closeSentAt[n] = TimeCurrent();
      return true;
     }

   // Lý do không được vào lệnh mới / đặt lệnh đảo ở cấp bot. Rỗng = được.
   string            BotBlock(datetime now)
     {
      if(blockedWhy != "")
         return blockedWhy;
      if(!m_reconciled)
         return "Đang chờ kết nối sàn để đối chiếu lệnh";
      if(hardStop)
         return "Dừng hẳn (chạm giới hạn lỗ tổng) - chờ bạn bấm cho chạy lại";
      if(recovery)
         return "Khôi phục: chờ bạn xác nhận lệnh";
      if(closing)
         return "Đang đóng lệnh: " + closingWhy;
      if(!botOn)
         return "Bot đang TẮT";
      if(now < pauseUntil)
         return PauseText(pauseWhy) + " tới " + TimeToString(pauseUntil + mc.vnOffset * 3600, TIME_MINUTES) + " VN";
      if(ex.CoolingDown())
         return "Ngắt tạm 30 giây vì lỗi gửi lệnh liên tiếp";
      return "";
     }

   MarketCfg         Cfg(void) { MarketCfg c = mc; c.timeFilter = timeOn; return c; }

   // Yêu cầu mở/đặt lệnh chờ đảo đang chờ gửi lại mà bot vừa bị chặn (hết giờ, NGHỈ, TẮT...): bỏ, không gửi lại
   void              CancelBlockedRequests(datetime now)
     {
      if(!ex.Busy(RQ_OPEN) && !ex.Busy(RQ_FLIP_PLACE))
         return;
      bool blocked = BotBlock(now) != "" || MustCloseByTime(now);
      if(blocked && ex.Busy(RQ_OPEN))
        {
         ex.Cancel(RQ_OPEN);
         st.Del(SK_REQ_KIND);
         m_log.Add("huy_gui_lai", "Bỏ yêu cầu mở lệnh đang chờ gửi lại vì bot vừa bị chặn vào lệnh");
        }
      if(blocked && ex.Busy(RQ_FLIP_PLACE))
         ex.Cancel(RQ_FLIP_PLACE);
     }

   void              TryEntry(const MqlTick &t, const SignalPick &picks[], int n, datetime touchClose)
     {
      string block = BotBlock(t.time);
      // chưa dọn xong dữ liệu lệnh trước (thông báo giao dịch đang tới) thì chưa vào, để không trộn dữ liệu hai lệnh
      if(block != "" || hasPos || posCount > 0 || ex.AnyBusy() || st.Get(SK_POS, 0) != 0 || m_goneSince != 0)
         return;
      MarketCfg c = Cfg();
      for(int i = 0; i < n; i++)
        {
         if(picks[i].type != SIG_FLIPPED && !(s.allowFresh && picks[i].type == SIG_FRESH))
            continue;
         int dir = picks[i].dir;
         double spread = t.ask - t.bid;
         bool bySpread;
         double B = StepB(atrM5, spread, s.stepAtrMult, s.stepMinSpreadMult, SymbolInfoDouble(m_sym, SYMBOL_TRADE_TICK_SIZE), _Digits, bySpread);
         int flags = 0;
         if(bias == 0 || bias != dir)
            flags |= FL_BIAS;
         if(picks[i].z.score < s.minEntryScore)
            flags |= FL_SCORE;
         if(!RoomOk(zones, dir, t.bid, spread, B, s.strongScore, s.minRoomB))
            flags |= FL_ROOM;
         flags |= MarketFlags(c, m_sym, t.time, spread, news.available, newsWin);
         if(t.time - touchClose >= 1800 || B <= 0.0)
            flags |= FL_NOENTRY;
         string zoneText = TfText(picks[i].z.tf) + " " + CZones::KindName(picks[i].z) + " điểm " + (string)picks[i].z.score;
         if((dir > 0 && !buyOn) || (dir < 0 && !sellOn))
           {
            m_log.Add("bo_qua", "Có tín hiệu " + (dir > 0 ? "MUA" : "BÁN") + " (" + zoneText + ") nhưng chiều này đang tắt");
            continue;
           }
         if(flags != 0)
           {
            m_log.Add("bo_qua", "Có tín hiệu " + (dir > 0 ? "MUA" : "BÁN") + " (" + zoneText + ") nhưng: " + FlagText(flags));
            continue;
           }
         double want = dir > 0 ? t.ask : t.bid;
         double sl = ex.Norm(want - dir * B);
         double lot = ex.NormVol(lotSize);
         double risk = money.TradeRisk(dir, lot, want, sl, s.slipBuffer);
         double maxRisk = s.riskPct / 100.0 * money.equity;
         if(risk > maxRisk)
           {
            lastSkip = "rủi ro " + DoubleToString(risk, 2) + " vượt " + DoubleToString(s.riskPct, 1) + "% (" + DoubleToString(maxRisk, 2) + ")";
            m_log.Add("bo_qua", "Có tín hiệu nhưng " + lastSkip);
            continue;
           }
         if(money.DayUsed() + risk > money.DayLimit(s))
           {
            lastSkip = "không còn đủ ngân sách lỗ ngày";
            m_log.Add("bo_qua", "Có tín hiệu nhưng " + lastSkip);
            continue;
           }
         string why;
         if(!money.MarginOk(dir, lot, want, s, why))
           {
            lastSkip = why;
            m_log.Add("bo_qua", "Có tín hiệu nhưng " + why);
            continue;
           }
         // Lưu ý định trước khi gửi: giá mong muốn, dừng lỗ, B, vùng; để OnTradeTransaction và khởi động lại dùng
         st.Set(SK_POS_B, B);
         st.Set(SK_POS_DIR, dir);
         st.Set(SK_POS_ZONE, picks[i].z.id);
         st.Set(SK_WANT_OPEN, want);
         st.Set(SK_WANT_SL, sl);
         st.Del(SK_WANT_SL_ID);
         st.Set(SK_REQ_KIND, 1);
         st.Set(SK_REQ_TIME, (double)t.time);
         st.Flush();
         m_sendMsc = GetTickCount64();
         m_log.Add("vao_lenh", (dir > 0 ? "MUA " : "BÁN ") + DoubleToString(lot, 2) + " giá " + DoubleToString(want, _Digits) + " dừng lỗ "
                   + DoubleToString(sl, _Digits) + " bước " + DoubleToString(B, 2) + " | chạm lần đầu " + zoneText);
         if(!ex.Open(dir, lot, sl, TAG_OPEN) && !ex.Busy(RQ_OPEN))
           {
            st.Del(SK_REQ_KIND);
            m_log.Add("loi_vao_lenh", "Không vào được lệnh");
           }
         return;
        }
     }

   // Mỗi nến: đếm số nến liền nhau giá đóng trong dải cản, rồi tính lại cản đối diện
   void              UpdateOpp(double bid, double close)
     {
      bool inside = m_oppEdge > 0.0 && close >= m_oppLo && close <= m_oppHi;
      barsInOpp = inside ? barsInOpp + 1 : 0;
      if(hasPos)
         RecalcOpp(posDir, bid);
      else
         m_oppEdge = m_oppLo = m_oppHi = 0.0;
     }

   // Gửi dời dừng lỗ; nếu sàn nhận thì ghi ngay mức mới (để đo trượt và đặt lệnh chờ đảo theo đúng mức mới)
   bool              SendSl(double target)
     {
      if(!ex.ModifySL(posTicket, target))
         return false;
      posSl = target;
      st.Set(SK_WANT_SL, target);
      st.Set(SK_WANT_SL_ID, st.Get(SK_POS, 0));
      return true;
     }

   void              ManagePosition(const MqlTick &t)
     {
      if(posB <= 0.0)
         return;
      double px = posDir > 0 ? t.bid : t.ask;
      // Lệnh không có dừng lỗ trên sàn: đặt ngay dừng lỗ cách giá vào 1 bước; giá đã qua mức đó thì đóng
      if(posSl <= 0.0 && !m_needSlReset)
        {
         double sl = ex.Norm(posOpen - posDir * posB);
         if((px - sl) * posDir <= ex.minDist)
            StartClosing("Lệnh không có dừng lỗ và giá đã qua mức dừng lỗ 1 bước");
         else
            if(!ex.Busy(RQ_SL))
               SendSl(sl);
         return;
        }
      // Sau khi khớp: đặt lại dừng lỗ tính từ giá khớp thật, vẫn 1 bước; không đặt được thì đóng ngay
      if(m_needSlReset)
        {
         double sl = ex.Norm(posOpen - posDir * posB);
         if(MathAbs(sl - posSl) < SymbolInfoDouble(m_sym, SYMBOL_TRADE_TICK_SIZE) / 2)
            m_needSlReset = false;
         else
            if(!ex.Busy(RQ_SL))
              {
               if((px - sl) * posDir > ex.minDist && SendSl(sl))
                  m_needSlReset = false;
               else
                  if(!ex.Busy(RQ_SL))
                    {
                     m_needSlReset = false;
                     StartClosing("Không đặt được dừng lỗ theo giá khớp thật");
                    }
              }
         return;
        }
      double target = posSl;
      atZone = false;
      if(newsWin)
        {
         // siết một lần khi vào cửa sổ tin (nếu đang lời thì dừng lỗ về hòa vốn); trong cửa sổ không dời gì thêm.
         // Chỉ đánh dấu "đã siết" khi đã gửi được hoặc không cần siết; bận thì thử lại tick sau.
         if(!m_newsTightened)
           {
            double be = ex.Norm(posOpen);
            bool need = (px - posOpen) * posDir > 0.0 && (be - posSl) * posDir > 0.0 && (px - be) * posDir > ex.minDist;
            if(!need)
               m_newsTightened = true;
            else
               if(!ex.Busy(RQ_SL) && SendSl(be))
                 {
                  m_newsTightened = true;
                  m_log.Add("siet_truoc_tin", "Sắp có tin mạnh: dừng lỗ về hòa vốn " + DoubleToString(be, _Digits));
                 }
           }
         return;
        }
      m_newsTightened = false;
      // thang bậc
      int steps = (int)MathFloor((px - posOpen) * posDir / posB + 1e-9);
      if(steps >= 1)
        {
         double v = posOpen + posDir * (steps - 1) * posB;
         if((v - target) * posDir > 0.0)
            target = v;
        }
      // khóa lời tại cản: khoảng cách theo Bid tới mép gần < 1B → dừng lỗ cách giá 0,5B
      if(m_oppEdge > 0.0)
        {
         double dist = posDir > 0 ? m_oppEdge - t.bid : t.bid - m_oppEdge;
         if(dist < s.lockDistB * posB)
           {
            atZone = true;
            double lock = px - posDir * s.lockOffsetB * posB;
            if((lock - target) * posDir > 0.0)
               target = lock;
           }
        }
      target = ex.Norm(target);
      if((target - posSl) * posDir >= SymbolInfoDouble(m_sym, SYMBOL_TRADE_TICK_SIZE) && (px - target) * posDir > ex.minDist && !ex.Busy(RQ_SL))
         SendSl(target);
     }

   // đảo chiều có điều kiện: đặt sẵn lệnh chờ ngược chiều đúng tại giá dừng lỗ; không đúng điều kiện thì gỡ
   void              ManageFlip(const MqlTick &t)
     {
      if(flipMode == FLIP_OFF || !hasPos || posSl <= 0.0)
        {
         if(hasFlip && !ex.Busy(RQ_FLIP_DEL))
            ex.Delete(flipTicket);
         return;
        }
      int nd = -posDir;
      string why = FlipBlock(t, nd);
      if(why != "")
        {
         if(hasFlip && !ex.Busy(RQ_FLIP_DEL))
           {
            ex.Delete(flipTicket);
            m_log.Add("huy_dao", "Gỡ lệnh chờ đảo: " + why);
           }
         return;
        }
      double price = ex.Norm(posSl);
      double ref = nd > 0 ? t.ask : t.bid;
      if(MathAbs(ref - price) <= ex.minDist)
         return;   // không đặt được đúng giá dừng lỗ (luật sàn): không đảo, không dịch giá
      datetime bar = iTime(m_sym, PERIOD_M5, 0);
      if(price == m_flipFailPrice && bar == m_flipFailBar)
         return;   // vừa bị sàn từ chối hẳn ở đúng giá này trong nến này: chờ giá dừng lỗ đổi hoặc sang nến mới
      double B = StepNow(t);
      double sl = ex.Norm(price - nd * B);
      if(!hasFlip)
        {
         if(ex.Busy(RQ_FLIP_PLACE))
            return;
         st.Set(SK_FLIP_B, B);   // ghi B trước khi gửi: lần gửi lại thành công vẫn có B đúng
         if(ex.PlaceStop(nd, posVol, price, sl, TAG_FLIP))
            m_log.Add("dat_dao", "Đặt sẵn " + (nd > 0 ? "MUA" : "BÁN") + " đảo chiều tại " + DoubleToString(price, _Digits));
         else
            if(!ex.Busy(RQ_FLIP_PLACE))
              {
               m_flipFailPrice = price;
               m_flipFailBar = bar;
              }
         return;
        }
      if(MathAbs(flipPrice - price) >= SymbolInfoDouble(m_sym, SYMBOL_TRADE_TICK_SIZE) / 2 && !ex.Busy(RQ_FLIP_MOD))
        {
         st.Set(SK_FLIP_B, B);
         if(!ex.ModifyOrder(flipTicket, price, sl) && !ex.Busy(RQ_FLIP_MOD))
           {
            m_flipFailPrice = price;
            m_flipFailBar = bar;
           }
        }
     }

   string            FlipBlock(const MqlTick &t, int nd)
     {
      string block = BotBlock(t.time);
      if(block != "")
         return block;
      if(st.Get(SK_IS_FLIP, 0) > 0.0)
         return "lệnh này đã là lệnh đảo, không đảo tiếp (Lab chưa đo loại này)";
      if((nd > 0 && !buyOn) || (nd < 0 && !sellOn))
         return "chiều đảo đang tắt";
      if(newsWin)
         return "trong cửa sổ tin";
      int f = MarketFlags(Cfg(), m_sym, t.time, t.ask - t.bid, news.available, false);
      if(f != 0)
         return FlagText(f);
      double px = posDir > 0 ? t.bid : t.ask;
      if(zones.InsideStrong(posSl, s.strongScore))
         return "giá dừng lỗ nằm trong cản mạnh";
      if(barsInOpp > s.maxBarsInZone)
         return "nằm trong dải cản quá " + (string)s.maxBarsInZone + " nến";
      int recent = 3 * PeriodSeconds(PERIOD_M5) + 300;
      bool pushed = (zones.lastBreakDir == nd && t.time - zones.lastBreakTime <= recent)
                    || (zones.lastRejectDir == nd && t.time - zones.lastRejectTime <= recent);
      if(nd != bias && !pushed)
         return "chiều đảo không cùng hướng lớn và không vừa phá/bị đẩy lại tại vùng mạnh";
      // dừng lỗ ở hòa vốn vẫn có thể thành thua sau trượt giá: tính như thua khi xét phanh
      bool slLoss = (posSl - posOpen) * posDir < s.slipBuffer;
      if(slLoss && consLosses + 1 >= s.brakeLosses)
         return "sắp chạm phanh thua liên tiếp";
      // rủi ro lệnh đảo và ngân sách lỗ ngày
      double price = posSl;
      double B = StepNow(t);
      double risk = money.TradeRisk(nd, posVol, price, price - nd * B, s.slipBuffer);
      if(risk > s.riskPct / 100.0 * money.equity)
         return "rủi ro lệnh đảo vượt " + DoubleToString(s.riskPct, 1) + "%";
      double remain = money.RemainingLoss(posDir, posVol, px, posSl);
      if(money.DayUsed() + remain + risk > money.DayLimit(s))
         return "không còn đủ ngân sách lỗ ngày";
      string why;
      if(!money.MarginOk(nd, posVol, price, s, why))
         return why;
      return "";
     }

   static string     TfText(ENUM_TIMEFRAMES tf) { return tf == PERIOD_M15 ? "M15" : (tf == PERIOD_H1 ? "H1" : (tf == PERIOD_H4 ? "H4" : "Ngày")); }

   void              OnNewBar(const MqlTick &t, datetime bar)
     {
      atrM5 = AtrM5();
      datetime h1 = (datetime)((long)bar / 3600 * 3600);
      if(h1 != m_lastH1)
        {
         m_lastH1 = h1;
         biasH4 = StructureBias(m_sym, PERIOD_H4);
         biasH1 = StructureBias(m_sym, PERIOD_H1);
         bias = CombinedBias(biasH4, biasH1, s.biasMode);
        }
      zones.OnNewM5(bar, RecentSwingM5(m_sym, true), RecentSwingM5(m_sym, false), s.strongScore);
      MqlRates b[];
      if(CopyRates(m_sym, PERIOD_M5, bar - 1, 1, b) != 1)
         return;
      UpdateOpp(t.bid, b[0].close);
      SignalPick picks[];
      int unconfirmed;
      int n = PickSignals(zones.evZone, zones.evFlags, zones.evCount, b[0], picks, unconfirmed);
      if(n > 0)
         TryEntry(t, picks, n, b[0].time + PeriodSeconds(PERIOD_M5));
     }

   // Đo và dọn các deal ra của lệnh đang lưu mà xảy ra lúc EA tắt (thua liên tiếp, trượt giá)
   void              ProcessMissedDeals(long posId)
     {
      if(posId == 0 || !HistorySelectByPosition(posId))
         return;
      for(int i = 0; i < HistoryDealsTotal(); i++)
        {
         ulong d = HistoryDealGetTicket(i);
         long e = HistoryDealGetInteger(d, DEAL_ENTRY);
         if(d != 0 && (e == DEAL_ENTRY_OUT || e == DEAL_ENTRY_OUT_BY))
           {
            m_log.Add("deal_luc_tat", "Lệnh #" + (string)posId + " đã đóng lúc bot tắt: ghi nhận lại");
            OnDeal(d);
           }
        }
     }

   // đối chiếu dữ liệu lưu với lệnh thật (chỉ khi terminal đã kết nối sàn)
   void              Reconcile(void)
     {
      if(!ex.HedgingOk())
        {
         blockedWhy = "Tài khoản không phải kiểu hedging: bot không giao dịch";
         m_log.Add("khong_giao_dich", blockedWhy);
        }
      ulong pos[], ord[];
      int np = ex.Positions(pos), no = ex.Orders(ord);
      long want = (long)st.Get(SK_POS, 0);
      bool wantAlive = false;
      for(int i = 0; i < np; i++)
         if(PositionSelectByTicket(pos[i]) && PositionGetInteger(POSITION_IDENTIFIER) == want)
            wantAlive = true;
      if(want != 0 && !wantAlive)
         ProcessMissedDeals(want);
      // lệnh chờ đảo khớp lúc EA tắt: mã lệnh mới chính là mã lệnh chờ đã lưu, B của nó cũng đã lưu
      long flipId = (long)st.Get(SK_FLIP, 0);
      if(np == 1 && PositionSelectByTicket(pos[0]) && flipId != 0 && PositionGetInteger(POSITION_IDENTIFIER) == flipId && st.Get(SK_FLIP_B, 0) > 0.0)
        {
         st.Set(SK_POS, (double)flipId);
         st.Set(SK_POS_B, st.Get(SK_FLIP_B, 0));
         st.Set(SK_POS_DIR, PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 1 : -1);
         st.Set(SK_IS_FLIP, 1);
         st.Del(SK_FLIP);
         st.Del(SK_FLIP_B);
         want = flipId;
         m_log.Add("khoi_dong", "Lệnh đảo #" + (string)pos[0] + " đã khớp lúc bot tắt: nhận quản lý với B đã lưu");
        }
      if(np == 0 && no == 0)
        {
         st.ClearTrade();
         if(closing)
           {
            closing = false;
            st.Set(SK_CLOSING, 0);
           }
         m_log.Add("khoi_dong", "Không có lệnh nào của bot: chạy bình thường");
         return;
        }
      bool match = np == 1 && PositionSelectByTicket(pos[0]) && PositionGetInteger(POSITION_IDENTIFIER) == want && st.Get(SK_POS_B, 0) > 0.0
                   && PositionGetDouble(POSITION_SL) > 0.0;
      if(match && no <= 1)
        {
         m_log.Add("khoi_dong", "Lệnh #" + (string)pos[0] + " khớp dữ liệu đã lưu: quản lý tiếp");
         return;
        }
      string info = "";
      for(int i = 0; i < np; i++)
         if(PositionSelectByTicket(pos[i]))
            info += "#" + (string)pos[i] + " " + (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? "MUA" : "BÁN") + " "
                    + DoubleToString(PositionGetDouble(POSITION_VOLUME), 2) + " giá " + DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN), _Digits)
                    + (PositionGetDouble(POSITION_SL) > 0.0 ? " dừng lỗ " + DoubleToString(PositionGetDouble(POSITION_SL), _Digits) : " KHÔNG CÓ DỪNG LỖ") + "; ";
      if(no > 0)
         info += (string)no + " lệnh chờ";
      EnterRecovery("Có lệnh nhưng dữ liệu lưu thiếu/không khớp: " + info);
     }

   // Số liệu trượt giá "hôm nay" về 0 khi sang ngày VN mới, kể cả khi chưa có deal nào
   void              SlipDay(datetime now)
     {
      int day = YmdKey(VnDayStart(now, mc.vnOffset), mc.vnOffset);
      if(day == m_slipDay)
         return;
      m_slipDay = day;
      slipSum = 0.0;
      slipCount = 0;
      slipWorst = 0.0;
      st.Touch();   // mỗi ngày ghi lại dữ liệu lưu để terminal không tự xóa sau 4 tuần
     }

public:
   BotSettings       s;
   MarketCfg         mc;
   CZones            zones;
   CNews             news;
   CState            st;
   CExec             ex;
   CMoney            money;
   ENUM_BOT_STATE    state;
   string            reason;
   string            lastSkip;
   string            blockedWhy;                   // lý do bot không được giao dịch (ví dụ tài khoản không phải hedging)
   int               biasH4, biasH1, bias;
   double            atrM5;
   bool              newsWin;
   // lệnh đang quản lý
   bool              hasPos;
   int               posCount;                     // số lệnh thật của bot trên sàn
   ulong             posTicket;
   int               posDir;
   double            posOpen, posSl, posVol, posB, posProfit;
   bool              hasFlip;
   ulong             flipTicket;
   double            flipPrice;
   int               ordersCount;
   int               barsInOpp;
   bool              atZone;
   // trạng thái bot
   bool              botOn, buyOn, sellOn, timeOn;
   ENUM_FLIP_MODE    flipMode;
   double            lotSize;
   bool              hardStop;
   bool              recovery;
   string            recoveryInfo;
   double            recoveryB;                    // B đề xuất khi để bot quản lý lệnh ở KHÔI PHỤC
   bool              closing;
   string            closingWhy;
   datetime          pauseUntil;
   int               pauseWhy;
   int               consLosses;
   // trượt giá hôm nay
   double            slipSum;
   int               slipCount;
   double            slipWorst;

   bool              Init(const string sym, CJournal *log, string &why)
     {
      m_sym = sym;
      m_log = log;
      m_reconciled = false;
      m_orphanSince = 0;
      m_goneSince = 0;
      m_seenPosId = 0;
      m_lastBar = 0;
      m_lastH1 = 0;
      m_newsTightened = false;
      m_needSlReset = false;
      m_closeWant = 0.0;
      m_slipDay = 0;
      m_flipFailPrice = 0.0;
      m_flipFailBar = 0;
      m_oppEdge = m_oppLo = m_oppHi = 0.0;
      barsInOpp = 0;
      posCount = 0;
      ordersCount = 0;
      hasPos = false;
      hasFlip = false;
      lastSkip = "";
      blockedWhy = "";
      recoveryB = 0.0;
      slipSum = 0.0;
      slipCount = 0;
      slipWorst = 0.0;
      if(!st.Init(sym, s.magic))
        {
         why = "Tên khóa lưu trạng thái quá dài";
         return false;
        }
      if(!ex.Init(sym, s.magic, log, why))
         return false;
      money.Init(sym, s.magic, mc.vnOffset, GetPointer(st));
      m_hAtrM5 = iATR(sym, PERIOD_M5, 14);
      ZoneRules r;
      ZoneRulesDefault(r);
      if(m_hAtrM5 == INVALID_HANDLE || !zones.Init(sym, r))
        {
         why = "Không tạo được chỉ báo ATR";
         return false;
        }
      news.Init();
      // công tắc và trạng thái đã lưu
      botOn = st.Get(SK_BOT_ON, botOn ? 1 : 0) > 0.0;
      buyOn = st.Get(SK_BUY_ON, 1) > 0.0;
      sellOn = st.Get(SK_SELL_ON, 1) > 0.0;
      timeOn = st.Get(SK_TIME_ON, mc.timeFilter ? 1 : 0) > 0.0;
      flipMode = (ENUM_FLIP_MODE)(int)st.Get(SK_FLIP_MODE, (double)flipMode);
      lotSize = st.Get(SK_LOT, lotSize);
      if(MathAbs(lotSize - ex.volMin) > 1e-9 && MathAbs(lotSize - 2 * ex.volMin) > 1e-9)
         lotSize = s.lot;   // lot đã lưu không hợp với ký hiệu này: dùng lot trong cài đặt
      hardStop = st.Get(SK_HARD, 0) > 0.0;
      pauseUntil = (datetime)st.Get(SK_PAUSE, 0);
      pauseWhy = (int)st.Get(SK_PAUSE_WHY, 0);
      consLosses = (int)st.Get(SK_CONS, 0);
      recovery = false;
      closing = st.Get(SK_CLOSING, 0) > 0.0;   // đang đóng dở trước khi khởi động lại: đóng tiếp
      closingWhy = closing ? "Tiếp tục đóng lệnh sau khởi động lại" : "";
      return true;
     }

   void              Release(void)
     {
      zones.Release();
      IndicatorRelease(m_hAtrM5);
      st.Flush();
     }

   // Nạp lịch sử cho vùng giá (gọi ở tick đầu khi chỉ báo đã sẵn sàng)
   bool              Ready(void) { return zones.Ready() && BarsCalculated(m_hAtrM5) > 0; }

   void              Warmup(void)
     {
      zones.Load(60 * 288, s.strongScore);
      m_lastBar = iTime(m_sym, PERIOD_M5, 0);
      atrM5 = AtrM5();
      biasH4 = StructureBias(m_sym, PERIOD_H4);
      biasH1 = StructureBias(m_sym, PERIOD_H1);
      bias = CombinedBias(biasH4, biasH1, s.biasMode);
      m_lastH1 = (datetime)((long)m_lastBar / 3600 * 3600);
      m_seenPosId = 0;   // tính lại cản đối diện cho lệnh đang có ở tick tới
      m_log.Add("vung", "Nạp vùng xong: " + (string)zones.count + " vùng");
     }

   void              OnTick(void)
     {
      MqlTick t;
      if(!SymbolInfoTick(m_sym, t))
         return;
      // Đối chiếu lệnh chỉ khi terminal đã kết nối sàn (lúc OnInit danh sách lệnh có thể còn trống)
      if(!m_reconciled)
        {
         if(!TerminalInfoInteger(TERMINAL_CONNECTED) || AccountInfoInteger(ACCOUNT_LOGIN) == 0 || AccountInfoDouble(ACCOUNT_EQUITY) <= 0.0)
            return;
         Reconcile();
         m_reconciled = true;
        }
      datetime now = t.time;
      SlipDay(now);
      money.Update(now);
      news.Refresh(now);
      newsWin = mc.newsFilter && news.available && news.InWindow(now, s.newsBefore, s.newsAfter, s.fomcAfter);
      CancelBlockedRequests(now);
      ex.Process();
      Sync(t);
      CheckLimits(now);
      if(!closing && (posCount > 0 || ordersCount > 0) && MustCloseByTime(now))
         StartClosing("Hết giờ chạy hoặc sắp tới giờ nghỉ của sàn");
      if(closing)
         DoClosing();
      else
         if(hasPos && !recovery)
           {
            ManagePosition(t);
            ManageFlip(t);
           }
      datetime bar = iTime(m_sym, PERIOD_M5, 0);
      if(bar != m_lastBar && bar != 0)
        {
         m_lastBar = bar;
         OnNewBar(t, bar);
        }
      st.Flush();
     }

   void              UpdateState(datetime now)
     {
      SlipDay(now);
      if(blockedWhy != "")
        {
         state = ST_STOPPED;
         reason = blockedWhy;
        }
      else
         if(hardStop)
           {
            state = ST_STOPPED;
            reason = "Chạm giới hạn lỗ tổng: bấm 'Chạy lại' để tiếp tục";
           }
         else
            if(recovery)
              {
               state = ST_RECOVERY;
               reason = recoveryInfo;
              }
            else
               if(closing)
                 {
                  state = ST_CLOSING;
                  reason = closingWhy;
                 }
               else
                  if(hasPos)
                    {
                     state = atZone ? ST_AT_ZONE : ST_RUN;
                     reason = atZone ? "Gần cản mạnh: đã khóa lời" : (newsWin ? "Trong cửa sổ tin: giữ nguyên dừng lỗ" : "Đang dời dừng lỗ theo bước");
                    }
                  else
                    {
                     string b = BotBlock(now);
                     MqlTick t;
                     SymbolInfoTick(m_sym, t);
                     int f = MarketFlags(Cfg(), m_sym, now, t.ask - t.bid, news.available, newsWin);
                     if(b != "" || f != 0)
                       {
                        state = botOn ? ST_PAUSE : ST_WAIT;
                        reason = b != "" ? b : FlagText(f);
                       }
                     else
                       {
                        state = ST_WAIT;
                        reason = bias == 0 ? "Hướng lớn chưa rõ: chưa có chiều vào" : "Chờ giá chạm lần đầu vùng vừa lật";
                       }
                    }
     }

   // OnTradeTransaction: nạp/rút tiền, ghi nhận lệnh mới, đo trượt giá, đếm thua liên tiếp, phanh
   void              OnDeal(ulong deal)
     {
      if(!HistoryDealSelect(deal))
         return;
      long type = HistoryDealGetInteger(deal, DEAL_TYPE);
      if(type == DEAL_TYPE_BALANCE)
        {
         double amount = HistoryDealGetDouble(deal, DEAL_PROFIT);
         money.OnBalance(amount);
         m_log.Add("nap_rut", (amount >= 0 ? "Nạp " : "Rút ") + DoubleToString(MathAbs(amount), 2) + " " + AccountInfoString(ACCOUNT_CURRENCY)
                   + ": dời mốc lời/lỗ ngày/tuần/tổng, không tính là lời/lỗ");
         return;
        }
      if(HistoryDealGetInteger(deal, DEAL_MAGIC) != s.magic || HistoryDealGetString(deal, DEAL_SYMBOL) != m_sym)
         return;
      long entry = HistoryDealGetInteger(deal, DEAL_ENTRY);
      long reasonCode = HistoryDealGetInteger(deal, DEAL_REASON);
      double price = HistoryDealGetDouble(deal, DEAL_PRICE);
      double vol = HistoryDealGetDouble(deal, DEAL_VOLUME);
      long posId = HistoryDealGetInteger(deal, DEAL_POSITION_ID);
      int dealDir = type == DEAL_TYPE_BUY ? 1 : (type == DEAL_TYPE_SELL ? -1 : 0);
      if(dealDir == 0)
         return;
      MqlTick t;
      SymbolInfoTick(m_sym, t);
      if(entry == DEAL_ENTRY_IN)
        {
         bool fromFlip = HistoryDealGetString(deal, DEAL_COMMENT) == TAG_FLIP || (long)HistoryDealGetInteger(deal, DEAL_ORDER) == (long)st.Get(SK_FLIP, -1);
         double B = fromFlip ? st.Get(SK_FLIP_B, 0.0) : st.Get(SK_POS_B, 0.0);
         // lệnh đảo: giá mong muốn là giá đặt của lệnh chờ (bằng dừng lỗ của lệnh cũ)
         ulong order = (ulong)HistoryDealGetInteger(deal, DEAL_ORDER);
         double want = !fromFlip ? st.Get(SK_WANT_OPEN, price)
                       : (HistoryOrderSelect(order) ? HistoryOrderGetDouble(order, ORDER_PRICE_OPEN) : price);
         if(B <= 0.0)
           {
            B = StepNow(t);
            m_log.Add("thieu_B", "Không có B đã lưu cho lệnh vừa khớp: dùng B tính lại " + DoubleToString(B, 2));
           }
         st.Set(SK_POS, (double)posId);
         st.Set(SK_POS_B, B);
         st.Set(SK_POS_DIR, dealDir);
         st.Set(SK_WANT_OPEN, want);
         st.Set(SK_IS_FLIP, fromFlip ? 1 : 0);
         if(!fromFlip)
            st.Set(SK_WANT_SL_ID, (double)posId);   // dừng lỗ dự kiến đã lưu lúc gửi thuộc về lệnh này
         st.Del(SK_REQ_KIND);
         if(fromFlip)
           {
            st.Del(SK_FLIP);
            st.Del(SK_FLIP_B);
           }
         st.Flush();
         m_needSlReset = true;
         m_newsTightened = false;
         m_seenPosId = posId;
         RecalcOpp(dealDir, t.bid);
         barsInOpp = 0;
         double adv = Slip(dealDir, price, want, B, vol, t, fromFlip ? "vào lệnh đảo" : "vào lệnh");
         m_log.Add("da_khop", (dealDir > 0 ? "MUA" : "BÁN") + string(" khớp ") + DoubleToString(price, _Digits) + " (mong muốn "
                   + DoubleToString(want, _Digits) + "), B = " + DoubleToString(B, 2));
         if(adv > s.maxEntrySlipB * B)
           {
            Pause(TimeCurrent() + s.slipPauseMinutes * 60, PW_SLIP);
            StartClosing("Trượt khi vào " + DoubleToString(adv, 2) + " > " + DoubleToString(s.maxEntrySlipB, 1) + "B");
           }
         return;
        }
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY)
         return;
      double profit = HistoryDealGetDouble(deal, DEAL_PROFIT) + HistoryDealGetDouble(deal, DEAL_SWAP) + HistoryDealGetDouble(deal, DEAL_COMMISSION);
      bool mine = (long)st.Get(SK_POS, 0) == posId;
      double B = mine ? st.Get(SK_POS_B, 0.0) : 0.0;
      bool bySl = reasonCode == DEAL_REASON_SL;
      // Giá mong muốn: dừng lỗ bot đã lưu cho đúng lệnh này, hoặc giá lúc bot gửi đóng; lệnh đóng không do bot thì không đo
      double want = 0.0;
      if(bySl && (long)st.Get(SK_WANT_SL_ID, 0) == posId)
         want = st.Get(SK_WANT_SL, 0.0);
      if(!bySl && reasonCode == DEAL_REASON_EXPERT)
         want = m_closeWant;
      m_closeWant = 0.0;
      double adv = want > 0.0 ? Slip(dealDir, price, want, B, vol, t, bySl ? "dừng lỗ" : "đóng lệnh") : 0.0;
      if(bySl && profit < 0.0)
         consLosses++;
      else
         if(profit > 0.0)
            consLosses = 0;
      st.Set(SK_CONS, consLosses);
      m_log.Add("dong_lenh", (bySl ? "Dính dừng lỗ" : "Đóng lệnh") + string(" ") + (profit >= 0 ? "+" : "") + DoubleToString(profit, 2)
                + " " + AccountInfoString(ACCOUNT_CURRENCY) + ", thua liên tiếp " + (string)consLosses);
      if(bySl && B > 0.0 && adv > s.maxSlSlipB * B)
         Pause(TimeCurrent() + s.slipPauseMinutes * 60, PW_SLIP);
      if(bySl && profit < 0.0 && consLosses >= s.brakeLosses)
        {
         Pause(TimeCurrent() + s.brakeMinutes * 60, PW_BRAKE);
         if(hasFlip)
            ex.Delete(flipTicket);
        }
      // lệnh gốc đóng không phải do dừng lỗ: lệnh chờ đảo nằm ở giá không còn là giá dừng lỗ, gỡ ngay
      if(mine && !bySl && hasFlip && !ex.Busy(RQ_FLIP_DEL))
         ex.Delete(flipTicket);
      // chỉ xóa dữ liệu của lệnh vừa đóng; dữ liệu lệnh chờ đảo / lệnh mới (nếu có) giữ nguyên
      if(mine)
         st.ClearPosition();
      st.Flush();
     }

   // AdverseSlippage: luôn dương = bất lợi. Deal MUA: khớp − mong muốn; deal BÁN: mong muốn − khớp.
   double            Slip(int dealDir, double fill, double want, double B, double vol, const MqlTick &t, const string what)
     {
      double adv = dealDir > 0 ? fill - want : want - fill;
      double cash = 0.0;
      if(!OrderCalcProfit(ORDER_TYPE_BUY, m_sym, vol, t.bid, t.bid + MathAbs(adv), cash))
         cash = 0.0;
      cash = adv >= 0.0 ? cash : -cash;
      SlipDay(TimeCurrent());
      slipSum += adv;
      slipCount++;
      slipWorst = MathMax(slipWorst, adv);
      m_log.Add("truot_gia", what + ": trượt bất lợi " + DoubleToString(adv, 3) + " giá = " + DoubleToString(cash, 2) + " tiền = "
                + (B > 0.0 ? DoubleToString(adv / B, 2) : "?") + "B; lệch thô " + DoubleToString(fill - want, 3) + "; chênh lệch "
                + DoubleToString(t.ask - t.bid, 3) + "; trễ " + (string)(GetTickCount64() - m_sendMsc) + " ms");
      return adv;
     }

   // ----- nút trên bảng -----
   void              SetBotOn(bool on) { botOn = on; st.Set(SK_BOT_ON, on ? 1 : 0); m_log.Add("nut", on ? "Bật bot" : "Tắt bot"); }
   void              SetBuy(bool on) { buyOn = on; st.Set(SK_BUY_ON, on ? 1 : 0); }
   void              SetSell(bool on) { sellOn = on; st.Set(SK_SELL_ON, on ? 1 : 0); }
   void              SetTime(bool on) { timeOn = on; st.Set(SK_TIME_ON, on ? 1 : 0); }
   void              SetFlip(ENUM_FLIP_MODE m) { flipMode = m; st.Set(SK_FLIP_MODE, (int)m); }
   void              SetLot(double lot) { lotSize = lot; st.Set(SK_LOT, lot); }
   void              CloseAll(void) { StartClosing("Bạn bấm đóng hết"); }

   void              Restart(void)
     {
      if(!hardStop)
         return;
      hardStop = false;
      st.Set(SK_HARD, 0);
      st.Set(SK_CAPITAL, AccountInfoDouble(ACCOUNT_EQUITY));
      st.Set(SK_CAP_TIME, (double)TimeCurrent());
      m_log.Add("chay_lai", "Bạn cho chạy lại sau giới hạn lỗ tổng; vốn gốc tính lại từ bây giờ");
     }

   // KHÔI PHỤC: để bot quản lý lệnh với B đề xuất (chỉ khi lệnh đã có dừng lỗ trên sàn)
   void              RecoveryManage(void)
     {
      ulong pos[];
      if(!recovery)
         return;
      if(ex.Positions(pos) != 1 || !PositionSelectByTicket(pos[0]))
        {
         m_log.Add("khoi_phuc", "Không để bot quản lý được: cần đúng 1 lệnh của bot (đang có " + (string)ArraySize(pos) + ")");
         return;
        }
      if(PositionGetDouble(POSITION_SL) <= 0.0)
        {
         m_log.Add("khoi_phuc", "Lệnh chưa có dừng lỗ: bấm 'Đặt dừng lỗ bảo vệ' trước");
         return;
        }
      long id = PositionGetInteger(POSITION_IDENTIFIER);
      st.Set(SK_POS, (double)id);
      st.Set(SK_POS_B, recoveryB);
      st.Set(SK_POS_DIR, PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 1 : -1);
      st.Del(SK_REQ_KIND);
      recovery = false;
      m_seenPosId = 0;   // tính cản đối diện ở tick tới
      m_log.Add("khoi_phuc_xong", "Bạn cho bot quản lý lệnh #" + (string)pos[0] + " với B = " + DoubleToString(recoveryB, 2));
     }

   void              RecoveryClose(void)
     {
      if(!recovery)
         return;
      StartClosing("Bạn chọn đóng lệnh khi khôi phục");
     }

   // KHÔI PHỤC, lệnh không có dừng lỗ: đặt dừng lỗ bảo vệ cách giá 1 bước
   void              RecoveryProtect(void)
     {
      ulong pos[];
      if(!recovery || ex.Positions(pos) != 1 || !PositionSelectByTicket(pos[0]) || PositionGetDouble(POSITION_SL) > 0.0)
         return;
      int dir = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 1 : -1;
      MqlTick t;
      SymbolInfoTick(m_sym, t);
      ex.ModifySL(pos[0], (dir > 0 ? t.bid : t.ask) - dir * recoveryB);
      m_log.Add("dung_lo_bao_ve", "Đặt dừng lỗ bảo vệ cách giá 1 bước (" + DoubleToString(recoveryB, 2) + ")");
     }

   bool              RecoveryNoSl(void)
     {
      ulong pos[];
      return recovery && ex.Positions(pos) == 1 && PositionSelectByTicket(pos[0]) && PositionGetDouble(POSITION_SL) <= 0.0;
     }

   // Kiểm tra giờ cả ở OnTimer (lúc 24:00 có thể không có tick)
   void              OnTimer(void)
     {
      if(!m_reconciled)
         return;
      datetime now = TimeTradeServer();
      CancelBlockedRequests(now);
      ex.Process();
      if(!closing && (posCount > 0 || ordersCount > 0) && MustCloseByTime(now))
         StartClosing("Hết giờ chạy hoặc sắp tới giờ nghỉ của sàn");
      if(closing)
         DoClosing();
      st.Flush();
     }
  };

#endif
