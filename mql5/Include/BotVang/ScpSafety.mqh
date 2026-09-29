// ScpSafety.mqh — cổng an toàn trước khi gửi: vốn lỗ, spread, tin, giờ nghỉ, độ mới báo giá (SPEC mục 12, 14.10).
// Không đọc quyết định giao dịch; chỉ trả lời "có được mở mới hay không" kèm lý do.
#ifndef SCP_SAFETY_MQH
#define SCP_SAFETY_MQH

#include "ScpTypes.mqh"
#include "ScpState.mqh"

// Mốc ngày/tuần theo múi giờ rủi ro (mặc định UTC+7, SPEC 14.1).
datetime ScpDayStart(datetime server, int offset_hours)
  {
   long v = (long)server + offset_hours * 3600;
   return (datetime)(v / 86400 * 86400 - offset_hours * 3600);
  }

datetime ScpWeekStart(datetime server, int offset_hours)
  {
   datetime d = ScpDayStart(server, offset_hours);
   MqlDateTime t;
   TimeToStruct(d + offset_hours * 3600, t);
   return d - ((t.day_of_week + 6) % 7) * 86400;
  }

class ScpSpreadGuard
  {
private:
   double            m_spread[512];
   long              m_time[512];
   int               m_count;
   int               m_head;

public:
                     ScpSpreadGuard() { m_count = 0; m_head = 0; }

   void              Reset() { m_count = 0; m_head = 0; }

   void              Add(double spread, long msc)
     {
      m_spread[m_head] = spread;
      m_time[m_head] = msc;
      m_head = (m_head + 1) % 512;
      if(m_count < 512)
         m_count++;
     }

   // Spread tăng bất thường: > 2 lần trung vị 60 giây, cần tối thiểu 30 mẫu (SPEC 14.10).
   bool              Ready(long msc)
     {
      int n=0;
      for(int i=0;i<m_count;i++) if(msc>=m_time[i] && msc-m_time[i]<=60000) n++;
      return n>=30;
     }

   bool              Spike(double spread_now, long msc, double multiple, int min_samples)
     {
      if(m_count < min_samples)
         return false;
      double window[512];
      int n = 0;
      for(int i = 0; i < m_count; i++)
        {
         if(msc - m_time[i] > 60000)
            continue;
         window[n++] = m_spread[i];
        }
      if(n < min_samples)
         return false;
      // Sắp xếp chọn trung vị (mảng nhỏ, chấp nhận O(n²) trong giới hạn an toàn).
      for(int i = 1; i < n; i++)
        {
         double v = window[i];
         int j = i - 1;
         while(j >= 0 && window[j] > v)
           {
            window[j + 1] = window[j];
            j--;
           }
         window[j + 1] = v;
        }
      double median = window[n / 2];
      if(median <= 0.0)
         return false;
      return (spread_now > multiple * median);
     }
  };

class ScpNewsGuard
  {
private:
   bool              m_available;
   int               m_count;
   datetime          m_time[256];

public:
                     ScpNewsGuard() { m_available = false; m_count = 0; }

   bool              Available()
     {
      // Một file có sự kiện quá khứ không chứng minh lịch còn phủ ngày hiện tại.
      datetime now=TimeCurrent();
      return m_available && m_count>0 && m_time[0]<=now && m_time[m_count-1]>=now+86400;
     }
   int               Count() { return m_count; }

   // Đọc lịch tin đã xuất (Common\Files\BotVang\news_usd.csv, cột đầu là giờ sàn).
   void              Load()
     {
      m_available = false;
      m_count = 0;
      int fh = FileOpen("BotVang\\news_usd.csv", FILE_COMMON | FILE_READ | FILE_CSV | FILE_ANSI, ';');
      if(fh == INVALID_HANDLE)
         return;
      while(!FileIsEnding(fh) && m_count < 256)
        {
         string t = FileReadString(fh);
         // Bỏ dòng tiêu đề và dòng trống.
         if(StringLen(t) < 8 || StringFind(t, "time") == 0)
           {
            FileReadString(fh);
            FileReadString(fh);
            FileReadString(fh);
            continue;
           }
         datetime when = StringToTime(t);
         if(when > 0)
            m_time[m_count++] = when;
         FileReadString(fh);
         FileReadString(fh);
         FileReadString(fh);
        }
      FileClose(fh);
      m_available = (m_count > 0);
     }

   // Trong cửa sổ trước/sau tin mạnh (phút).
   bool              InWindow(datetime now, int before_min, int after_min)
     {
      if(!m_available)
         return false;
      for(int i = 0; i < m_count; i++)
         if(now >= m_time[i] - before_min * 60 && now <= m_time[i] + after_min * 60)
            return true;
      return false;
     }
  };

class ScpRiskLedger
  {
private:
   ScpState         *m_st;
   int               m_offset;
   double            m_risk_pct;
   double            m_day_pct;
   double            m_week_pct;
   double            m_total_pct;
   long              m_magic;
   string            m_symbol;
   bool              m_history_ok;

   int               DayKey(datetime now)
     {
      MqlDateTime t;
      TimeToStruct(ScpDayStart(now, m_offset) + m_offset * 3600, t);
      return t.year * 10000 + t.mon * 100 + t.day;
     }

   int               WeekKey(datetime now)
     {
      MqlDateTime t;
      TimeToStruct(ScpWeekStart(now, m_offset) + m_offset * 3600, t);
      return t.year * 10000 + t.mon * 100 + t.day;
     }

public:
   double            Equity;
   double            DayRef, WeekRef, Capital;
   double            DayPnl, WeekPnl, TotalPnl;
   double            DayLimit, WeekLimit, TotalLimit;
   bool              Locked;
   string            LockReason;

                     ScpRiskLedger()
     {
      m_st = NULL;
      m_offset = 7;
      m_risk_pct = 0.25;
      m_day_pct = 2.0;
      m_week_pct = 5.0;
      m_total_pct = 8.0;
      Equity = DayRef = WeekRef = Capital = 0.0;
      DayPnl = WeekPnl = TotalPnl = 0.0;
      DayLimit = WeekLimit = TotalLimit = 0.0;
      Locked = false;
      LockReason = "";
     }

   void              Init(ScpState *st, long magic, const string sym, int offset_hours,
                          double risk_pct, double day_pct, double week_pct, double total_pct)
     {
      m_st = st;
      m_magic = magic;
      m_symbol = sym;
      m_offset = offset_hours;
      m_risk_pct = risk_pct;
      m_day_pct = day_pct;
      m_week_pct = week_pct;
      m_total_pct = total_pct;
     }

   double            RiskPercent() { return m_risk_pct; }
   bool              LockedOut() { return Locked; }
   string            LockText() { return LockReason; }

   // PnL ròng thuộc bot kể từ mốc thời gian: deal đã đóng cộng lỗ/lãi nổi (SPEC 14.10).
   double            PnlSince(datetime from)
     {
      double sum = 0.0;
      bool ready=HistorySelect(from, TimeCurrent() + 60);
      if(!ready) m_history_ok=false;
      if(ready)
        {
         for(int i = 0; i < HistoryDealsTotal(); i++)
           {
            ulong d = HistoryDealGetTicket(i);
            if(d == 0)
               continue;
            if(HistoryDealGetInteger(d, DEAL_MAGIC) != m_magic)
               continue;
            if(HistoryDealGetString(d, DEAL_SYMBOL) != m_symbol)
               continue;
            long e = HistoryDealGetInteger(d, DEAL_ENTRY);
            if(e != DEAL_ENTRY_IN && e != DEAL_ENTRY_OUT && e != DEAL_ENTRY_OUT_BY && e != DEAL_ENTRY_INOUT)
               continue;
            sum += HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_SWAP) +
                   HistoryDealGetDouble(d, DEAL_COMMISSION)+HistoryDealGetDouble(d,DEAL_FEE);
           }
        }
      return sum + FloatingPnl();
     }

   // Lỗ/lãi nổi của vị thế thuộc bot: dùng giá thoát được (mua theo Bid, bán theo Ask).
   double            FloatingPnl()
     {
      double sum = 0.0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong t = PositionGetTicket(i);
         if(t == 0)
            continue;
         if(PositionGetString(POSITION_SYMBOL) != m_symbol)
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != m_magic)
            continue;
         long dir = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? +1 : -1;
         double vol = PositionGetDouble(POSITION_VOLUME);
         double open = PositionGetDouble(POSITION_PRICE_OPEN);
         double exit = (dir > 0) ? SymbolInfoDouble(m_symbol, SYMBOL_BID) : SymbolInfoDouble(m_symbol, SYMBOL_ASK);
         double money = 0.0;
         if(OrderCalcProfit(dir > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, m_symbol, vol, open, exit, money))
            sum += money+PositionGetDouble(POSITION_SWAP);
         else m_history_ok=false;
        }
      return sum;
     }

   // Nạp/rút tiền: dời mốc vốn đúng bằng số tiền, không xóa bộ đếm lỗ.
   void              OnBalance(double delta)
     {
      if(m_st == NULL)
         return;
      if(m_st.Has(SK_CAP))
         m_st.Set(SK_CAP, m_st.Get(SK_CAP) + delta);
      if(m_st.Has(SK_DAY_REF))
         m_st.Set(SK_DAY_REF, m_st.Get(SK_DAY_REF) + delta);
      if(m_st.Has(SK_WEEK_REF))
         m_st.Set(SK_WEEK_REF, m_st.Get(SK_WEEK_REF) + delta);
     }

   // Cập nhật mốc vốn và số lỗ hiện tại; mốc lưu bền qua khởi động lại.
   void              Update(datetime now)
     {
      if(m_st == NULL)
         return;
      if(!(bool)TerminalInfoInteger(TERMINAL_CONNECTED))
        { Locked=true; LockReason="mất kết nối, không mở mới"; return; }
      Equity = AccountInfoDouble(ACCOUNT_EQUITY);
      if(Equity <= 0.0) { Locked=true; LockReason="thiếu vốn tham chiếu"; return; }
      if(!m_st.Has(SK_CAP))
        {
         m_st.Set(SK_CAP, Equity);
         m_st.Set(SK_CAP_TIME, (double)now);
        }
      int dk = DayKey(now);
      if((int)m_st.Get(SK_DAY_KEY) != dk)
        {
         m_st.Set(SK_DAY_KEY, dk);
         m_st.Set(SK_DAY_REF, Equity);
         m_st.Set(SK_LOCK_DAY, 0);
        }
      int wk = WeekKey(now);
      if((int)m_st.Get(SK_WEEK_KEY) != wk)
        {
         m_st.Set(SK_WEEK_KEY, wk);
         m_st.Set(SK_WEEK_REF, Equity);
         m_st.Set(SK_LOCK_WEEK, 0);
        }
      Capital = m_st.Get(SK_CAP, Equity);
      DayRef = m_st.Get(SK_DAY_REF, Equity);
      WeekRef = m_st.Get(SK_WEEK_REF, Equity);
      DayLimit = DayRef * m_day_pct / 100.0;
      WeekLimit = WeekRef * m_week_pct / 100.0;
      TotalLimit = Capital * m_total_pct / 100.0;
      datetime capTime = (datetime)m_st.Get(SK_CAP_TIME, (double)now);
      m_history_ok=true;
      DayPnl = PnlSince(ScpDayStart(now, m_offset));
      WeekPnl = PnlSince(ScpWeekStart(now, m_offset));
      TotalPnl = PnlSince(capTime);
      if(!m_history_ok) { Locked=true; LockReason="thiếu lịch sử/tính tiền; khóa mở mới"; return; }
      if(TotalLimit>0 && -TotalPnl>=TotalLimit) m_st.Set(SK_LOCK_TOTAL,1);
      if(DayLimit>0 && -DayPnl>=DayLimit) m_st.Set(SK_LOCK_DAY,1);
      if(WeekLimit>0 && -WeekPnl>=WeekLimit) m_st.Set(SK_LOCK_WEEK,1);
      Locked = false;
      LockReason = "";
      if(m_st.Get(SK_LOCK_TOTAL)>0) { Locked=true; LockReason="khóa giới hạn tổng"; }
      else if(m_st.Get(SK_LOCK_WEEK)>0) { Locked=true; LockReason="khóa giới hạn tuần"; }
      else if(m_st.Get(SK_LOCK_DAY)>0) { Locked=true; LockReason="khóa giới hạn ngày"; }
      m_st.Flush();
      if(TotalLimit > 0.0 && -TotalPnl >= TotalLimit)
        {
         Locked = true;
         LockReason = "chạm giới hạn lỗ tổng";
        }
      else
         if(DayLimit > 0.0 && -DayPnl >= DayLimit)
           {
            Locked = true;
            LockReason = "chạm giới hạn lỗ ngày";
           }
         else
            if(WeekLimit > 0.0 && -WeekPnl >= WeekLimit)
              {
               Locked = true;
               LockReason = "chạm giới hạn lỗ tuần";
              }
     }
  };

// Số giây tới lần nghỉ sàn kế tiếp; 0 là không xác định.
int ScpSecondsToSessionEnd(const string sym, datetime now)
  {
   MqlDateTime t;
   TimeToStruct(now, t);
   int best = 0;
   for(int d = 0; d < 4; d++)
     {
      int dow = (t.day_of_week + d) % 7;
      datetime from, to;
      for(int idx = 0; idx < 8; idx++)
        {
         if(!SymbolInfoSessionTrade(sym, (ENUM_DAY_OF_WEEK)dow, idx, from, to))
            break;
         datetime day_base = (datetime)((long)now - (long)(t.hour * 3600 + t.min * 60 + t.sec) + (long)d * 86400);
         datetime close_at = (datetime)((long)day_base + (long)to);
         if(close_at > now)
           {
            int secs = (int)(close_at - now);
            if(best == 0 || secs < best)
               best = secs;
           }
        }
     }
   return best;
  }

#endif // SCP_SAFETY_MQH
