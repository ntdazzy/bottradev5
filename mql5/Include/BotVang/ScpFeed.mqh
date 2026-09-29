// ScpFeed.mqh — nạp nến đã đóng và báo giá từ MT5 vào chuỗi của bot (SPEC mục 4.1, 14.1).
// Chỉ đọc dữ liệu; không gửi lệnh.
#ifndef SCP_FEED_MQH
#define SCP_FEED_MQH

#include "ScpTypes.mqh"
#include "ScpSeries.mqh"

class ScpFeed
  {
private:
   string            m_symbol;
   ScpFrames        *m_fr;
   datetime          m_last_pushed[SCP_TF_COUNT];
   datetime          m_forming[SCP_TF_COUNT];
   int               m_late_count[SCP_TF_COUNT];
   double            m_last_bid, m_last_ask;
   datetime          m_last_quote_time;
   ScpQuote          m_quote;
   bool              m_gap;

public:
                     ScpFeed()
     {
      m_symbol = "";
      m_fr = NULL;
      for(int i = 0; i < SCP_TF_COUNT; i++)
        {
         m_last_pushed[i] = 0;
         m_forming[i] = 0;
         m_late_count[i] = 0;
        }
      m_last_bid = 0.0;
      m_last_ask = 0.0;
      m_last_quote_time = 0;
      ZeroMemory(m_quote);
     }

   void              Init(const string sym, ScpFrames *fr)
     {
      m_symbol = sym;
      m_fr = fr;
      ZeroMemory(m_quote); m_gap=false;
      for(int i=0;i<SCP_TF_COUNT;i++)
        { m_last_pushed[i]=0; m_forming[i]=0; m_late_count[i]=0; }
     }

   int               LateCount(ENUM_SCP_TF tf) { return m_late_count[tf]; }
   bool              Gap() { return m_gap; }

   // Nạp nến lịch sử đã đóng lúc khởi động để bối cảnh có sẵn (SPEC 15.2).
   int               Warmup(int bars)
     {
      int pushed = 0;
      for(int i = 0; i < SCP_TF_COUNT; i++)
        {
         MqlRates r[];
         ArraySetAsSeries(r, false);
         int got = CopyRates(m_symbol, SCP_TF_PERIODS[i], 0, bars, r);
         if(got <= 1)
            continue;
         ScpSeries *s = m_fr.Get(i);
         if(s == NULL)
            continue;
         // Bỏ nến cuối cùng (còn đang chạy), chỉ nạp nến đã đóng.
         for(int k = 0; k < got - 1; k++)
           {
            ScpBar b;
            b.open_time = r[k].time;
            b.close_time = r[k].time + (datetime)PeriodSeconds(SCP_TF_PERIODS[i]);
            b.o = r[k].open;
            b.h = r[k].high;
            b.l = r[k].low;
            b.c = r[k].close;
            b.tick_volume = r[k].tick_volume;
            b.known_at = b.close_time;
            b.known_at_msc = -1;
            b.received_mono = GetTickCount();
            b.complete = true;
            if(s.PushBar(b))
              {
               m_last_pushed[i] = r[k].time;
               pushed++;
              }
           }
         m_forming[i] = (datetime)iTime(m_symbol, SCP_TF_PERIODS[i], 0);
        }
      return pushed;
     }

   // Nạp các nến đã đóng mới của mọi khung. `new_bar[i]` = khung i có nến mới.
   // Dùng iTime của nến đang chạy để biết vừa sang nến mới; chỉ khi đó mới đọc nến (giữ luồng tick ngắn).
   bool              UpdateFrames(bool &new_bar[])
     {
      ArrayResize(new_bar, SCP_TF_COUNT);
      m_gap=false;
      bool any = false;
      for(int i = 0; i < SCP_TF_COUNT; i++)
        {
         new_bar[i] = false;
         datetime t0 = (datetime)iTime(m_symbol, SCP_TF_PERIODS[i], 0);
         if(t0 <= 0)
            continue;
         if(m_forming[i] == 0)
           {
            m_forming[i] = t0;
            continue;
           }
         if(t0 == m_forming[i])
            continue;
         if(t0-m_forming[i]>PeriodSeconds(SCP_TF_PERIODS[i])) m_gap=true;
         MqlRates r[];
         ArraySetAsSeries(r, true);
         int got = CopyRates(m_symbol, SCP_TF_PERIODS[i], m_last_pushed[i] + 1, t0 - 1, r);
         if(got <= 0)
            continue;
         m_forming[i] = t0;
         // r[0] là nến đã đóng gần nhất.
         ScpSeries *s = m_fr.Get(i);
         if(s == NULL)
            continue;
         for(int k = got - 1; k >= 0; k--)
           {
            if(r[k].time <= m_last_pushed[i])
               continue;
            ScpBar b;
            b.open_time = r[k].time;
            b.close_time = r[k].time + (datetime)PeriodSeconds(SCP_TF_PERIODS[i]);
            b.o = r[k].open;
            b.h = r[k].high;
            b.l = r[k].low;
            b.c = r[k].close;
            b.tick_volume = r[k].tick_volume;
            datetime expected_close = b.close_time;
            long lateness = (long)TimeCurrent() - (long)expected_close;
            b.known_at = TimeCurrent();
            b.known_at_msc = -1;
            b.received_mono = GetTickCount();
            b.complete = true;
            if(lateness > 2)
               m_late_count[i]++;
            if(!s.PushBar(b))
               continue;
            m_last_pushed[i] = r[k].time;
            new_bar[i] = true;
            any = true;
           }
        }
      return any;
     }

   // Cập nhật báo giá; trả về true nếu có thay đổi giá/thời điểm.
   bool              UpdateQuote(ScpQuote &out)
     {
      MqlTick tick;
      if(!SymbolInfoTick(m_symbol, tick) || tick.bid <= 0 || tick.ask < tick.bid)
        { out = m_quote; return false; }
      if(tick.time_msc == m_quote.broker_msc && tick.bid == m_quote.bid && tick.ask == m_quote.ask)
        { out = m_quote; return false; }
      m_quote.bid = tick.bid;
      m_quote.ask = tick.ask;
      m_quote.time = tick.time;
      m_quote.broker_msc = tick.time_msc;
      m_quote.received_at = TimeGMT();
      m_quote.received_msc = GetTickCount();
      out = m_quote;
      return true;
     }

   ScpQuote          Quote() { return m_quote; }
  };

#endif // SCP_FEED_MQH
