// Tiền của bot: mốc Equity đầu ngày/tuần (lưu trong State), lời/lỗ ngày/tuần/tổng, giới hạn lỗ,
// rủi ro mỗi lệnh (OrderCalcProfit), ngân sách lỗ ngày, ký quỹ; thắng/thua hôm nay theo lịch sử deal của bot.
#ifndef BOTVANG_STATS_MQH
#define BOTVANG_STATS_MQH

#include "Types.mqh"
#include "State.mqh"

// Đầu ngày VN (00:00 VN) tính theo giờ sàn
datetime VnDayStart(datetime server, int vnOffset)
  {
   long vn = (long)server + vnOffset * 3600;
   return (datetime)(vn / 86400 * 86400 - vnOffset * 3600);
  }

// Đầu tuần VN (00:00 VN thứ Hai) tính theo giờ sàn
datetime VnWeekStart(datetime server, int vnOffset)
  {
   datetime day = VnDayStart(server, vnOffset);
   MqlDateTime t;
   TimeToStruct(day + vnOffset * 3600, t);
   return day - ((t.day_of_week + 6) % 7) * 86400;
  }

int YmdKey(datetime vnMidnightServer, int vnOffset)
  {
   MqlDateTime t;
   TimeToStruct(vnMidnightServer + vnOffset * 3600, t);
   return t.year * 10000 + t.mon * 100 + t.day;
  }

class CMoney
  {
private:
   string            m_sym;
   long              m_magic;
   int               m_vnOffset;
   CState           *m_st;

   // Giới hạn theo % mốc, hoặc theo USD (tài khoản Cent tính bằng USC: 1 USD = 100 USC)
   double            Limit(double pctOrUsd, double base, ENUM_LIMIT_UNIT unit) const
     {
      if(unit == LIMIT_PERCENT)
         return pctOrUsd / 100.0 * base;
      return AccountInfoString(ACCOUNT_CURRENCY) == "USC" ? pctOrUsd * 100.0 : pctOrUsd;
     }

public:
   double            equity;
   double            dayEq;
   double            weekEq;
   double            capital;
   double            dayPnl;
   double            weekPnl;
   double            totalPnl;
   int               winsToday;
   int               lossesToday;

   void              Init(const string sym, long magic, int vnOffset, CState *st)
     {
      m_sym = sym;
      m_magic = magic;
      m_vnOffset = vnOffset;
      m_st = st;
     }

   // Chụp mốc Equity ở tick đầu tiên sau 00:00 VN (ngày) và 00:00 VN thứ Hai (tuần); tính lời/lỗ hiện tại.
   // Chỉ gọi khi terminal đã kết nối sàn (trước đó Equity có thể bằng 0).
   void              Update(datetime now)
     {
      equity = AccountInfoDouble(ACCOUNT_EQUITY);
      if(equity <= 0.0)
         return;
      if(!m_st.Has(SK_CAPITAL))
        {
         m_st.Set(SK_CAPITAL, equity);
         m_st.Set(SK_CAP_TIME, (double)now);
        }
      int dk = YmdKey(VnDayStart(now, m_vnOffset), m_vnOffset);
      if((int)m_st.Get(SK_DAY_KEY) != dk)
        {
         m_st.Set(SK_DAY_KEY, dk);
         m_st.Set(SK_DAY_EQ, equity);
        }
      int wk = YmdKey(VnWeekStart(now, m_vnOffset), m_vnOffset);
      if((int)m_st.Get(SK_WEEK_KEY) != wk)
        {
         m_st.Set(SK_WEEK_KEY, wk);
         m_st.Set(SK_WEEK_EQ, equity);
        }
      dayEq = m_st.Get(SK_DAY_EQ, equity);
      weekEq = m_st.Get(SK_WEEK_EQ, equity);
      capital = m_st.Get(SK_CAPITAL, equity);
      dayPnl = equity - dayEq;
      weekPnl = equity - weekEq;
      totalPnl = equity - capital;
     }

   double            DayLimit(const BotSettings &s) const { return Limit(s.dayLoss, dayEq, s.limitUnit); }
   double            WeekLimit(const BotSettings &s) const { return Limit(s.weekLoss, weekEq, s.limitUnit); }
   double            TotalLimit(const BotSettings &s) const { return Limit(s.totalLoss, capital, s.limitUnit); }
   double            DayUsed(void) const { return MathMax(0.0, dayEq - equity); }   // đã gồm lệnh đang mở

   // Nạp/rút tiền không phải lời/lỗ: dời các mốc Equity ngày/tuần và vốn gốc đúng bằng số tiền nạp (+) hoặc rút (−)
   void              OnBalance(double amount)
     {
      string keys[] = {SK_DAY_EQ, SK_WEEK_EQ, SK_CAPITAL};
      for(int i = 0; i < 3; i++)
         if(m_st.Has(keys[i]))
            m_st.Set(keys[i], m_st.Get(keys[i]) + amount);
     }

   // 1 = chạm giới hạn ngày, 2 = tuần, 3 = tổng, 4 = đạt mục tiêu lời ngày, 5 = tuần; 0 = chưa
   int               LimitHit(const BotSettings &s) const
     {
      if(-totalPnl >= TotalLimit(s))
         return 3;
      if(-dayPnl >= DayLimit(s))
         return 1;
      if(-weekPnl >= WeekLimit(s))
         return 2;
      if(s.profitTargetOn && s.dayProfit > 0.0 && dayPnl >= Limit(s.dayProfit, dayEq, s.limitUnit))
         return 4;
      if(s.profitTargetOn && s.weekProfit > 0.0 && weekPnl >= Limit(s.weekProfit, weekEq, s.limitUnit))
         return 5;
      return 0;
     }

   // Rủi ro của một lệnh mới: lỗ nếu chạm dừng lỗ + đệm trượt giá (khoảng giá đổi ra tiền); không hoa hồng trên Standard/Cent
   double            TradeRisk(int dir, double lot, double entry, double sl, double slipBuffer) const
     {
      ENUM_ORDER_TYPE t = dir > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      double lossSl = 0.0, lossSlip = 0.0;
      if(!OrderCalcProfit(t, m_sym, lot, entry, sl, lossSl) || !OrderCalcProfit(t, m_sym, lot, entry, entry - dir * slipBuffer, lossSlip))
         return DBL_MAX;
      return MathAbs(lossSl) + MathAbs(lossSlip);
     }

   // Lỗ còn lại nếu lệnh đang chạy chạm dừng lỗ hiện tại (0 nếu dừng lỗ đã có lời)
   double            RemainingLoss(int dir, double lot, double price, double sl) const
     {
      double p = 0.0;
      if(!OrderCalcProfit(dir > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, m_sym, lot, price, sl, p))
         return DBL_MAX;
      return MathMax(0.0, -p);
     }

   // ký quỹ trống sau lệnh >= x% Equity và mức ký quỹ sau lệnh >= y%
   bool              MarginOk(int dir, double lot, double price, const BotSettings &s, string &why) const
     {
      double need = 0.0;
      if(!OrderCalcMargin(dir > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, m_sym, lot, price, need))
        {
         why = "không tính được ký quỹ";
         return false;
        }
      double eq = AccountInfoDouble(ACCOUNT_EQUITY);
      double used = AccountInfoDouble(ACCOUNT_MARGIN) + need;
      double freeAfter = AccountInfoDouble(ACCOUNT_MARGIN_FREE) - need;
      if(freeAfter < s.minFreeMarginPct / 100.0 * eq)
        {
         why = "ký quỹ trống sau lệnh dưới " + DoubleToString(s.minFreeMarginPct, 0) + "% Equity";
         return false;
        }
      if(used > 0.0 && eq / used * 100.0 < s.minMarginLevel)
        {
         why = "mức ký quỹ sau lệnh dưới " + DoubleToString(s.minMarginLevel, 0) + "%";
         return false;
        }
      return true;
     }

   // Thắng/thua hôm nay theo deal đóng của bot (đếm theo lời/lỗ của deal ra)
   void              CountToday(datetime now)
     {
      winsToday = 0;
      lossesToday = 0;
      if(!HistorySelect(VnDayStart(now, m_vnOffset), now + 60))
         return;
      for(int i = 0; i < HistoryDealsTotal(); i++)
        {
         ulong d = HistoryDealGetTicket(i);
         if(d == 0 || HistoryDealGetInteger(d, DEAL_MAGIC) != m_magic || HistoryDealGetString(d, DEAL_SYMBOL) != m_sym)
            continue;
         long e = HistoryDealGetInteger(d, DEAL_ENTRY);
         if(e != DEAL_ENTRY_OUT && e != DEAL_ENTRY_OUT_BY)
            continue;
         double p = HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_SWAP) + HistoryDealGetDouble(d, DEAL_COMMISSION);
         if(p >= 0.0)
            winsToday++;
         else
            lossesToday++;
        }
     }
  };

#endif
