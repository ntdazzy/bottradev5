// Gửi lệnh: đọc thông số từ sàn, khóa yêu cầu trùng, thử lại có giới hạn chỉ với lỗi tạm thời,
// xác minh trước khi thử lại lệnh mở/lệnh chờ đảo, ngắt tạm khi lỗi liên tiếp. Chỉ đụng lệnh đúng Magic + Symbol.
#ifndef BOTVANG_EXEC_MQH
#define BOTVANG_EXEC_MQH

#include "Journal.mqh"

#define RQ_OPEN        0
#define RQ_SL          1
#define RQ_CLOSE       2
#define RQ_FLIP_PLACE  3
#define RQ_FLIP_MOD    4
#define RQ_FLIP_DEL    5
#define RQ_COUNT       6

struct PendingReq
  {
   bool              active;
   int               attempt;
   ulong             dueMsc;       // lúc được thử lại (GetTickCount64)
   datetime          sentAt;
   string            tag;
   MqlTradeRequest   req;
  };

class CExec
  {
private:
   string            m_sym;
   long              m_magic;
   CJournal         *m_log;
   ENUM_ORDER_TYPE_FILLING m_fill;
   ENUM_ORDER_TYPE_TIME m_orderTime;
   bool              m_useDeviation;
   double            m_tick;
   int               m_digits;
   double            m_point;
   PendingReq        m_q[RQ_COUNT];
   int               m_errors;
   ulong             m_coolUntil;

   static bool       Transient(uint rc)
     {
      return rc == TRADE_RETCODE_REQUOTE || rc == TRADE_RETCODE_PRICE_CHANGED || rc == TRADE_RETCODE_TIMEOUT
             || rc == TRADE_RETCODE_TOO_MANY_REQUESTS || rc == TRADE_RETCODE_CONNECTION;
     }
   static bool       Accepted(uint rc) { return rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_PLACED || rc == TRADE_RETCODE_DONE_PARTIAL; }
   static string     KindName(int k)
     {
      string n[RQ_COUNT] = {"mở lệnh", "dời dừng lỗ", "đóng lệnh", "đặt lệnh chờ đảo", "dời lệnh chờ đảo", "hủy lệnh chờ đảo"};
      return k >= 0 && k < RQ_COUNT ? n[k] : "?";
     }

   // Yêu cầu mở/đặt lệnh chờ trước đó đã tới sàn chưa (phòng trường hợp bot chưa nhận phản hồi)
   bool              AlreadyDone(const PendingReq &p)
     {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong t = PositionGetTicket(i);
         if(t != 0 && PositionGetInteger(POSITION_MAGIC) == m_magic && PositionGetString(POSITION_SYMBOL) == m_sym
            && (PositionGetString(POSITION_COMMENT) == p.tag || (datetime)PositionGetInteger(POSITION_TIME) >= p.sentAt))
            return true;
        }
      for(int i = OrdersTotal() - 1; i >= 0; i--)
        {
         ulong t = OrderGetTicket(i);
         if(t != 0 && OrderGetInteger(ORDER_MAGIC) == m_magic && OrderGetString(ORDER_SYMBOL) == m_sym && OrderGetString(ORDER_COMMENT) == p.tag)
            return true;
        }
      if(HistorySelect(p.sentAt - 60, TimeCurrent() + 60))
         for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
           {
            ulong d = HistoryDealGetTicket(i);
            if(d != 0 && HistoryDealGetInteger(d, DEAL_MAGIC) == m_magic && HistoryDealGetString(d, DEAL_SYMBOL) == m_sym
               && HistoryDealGetInteger(d, DEAL_ENTRY) == DEAL_ENTRY_IN && HistoryDealGetString(d, DEAL_COMMENT) == p.tag)
               return true;
           }
      return false;
     }

   bool              DoSend(int kind)
     {
      MqlTradeResult res;
      ZeroMemory(res);
      m_q[kind].req.price = m_q[kind].req.action == TRADE_ACTION_DEAL
                            ? (m_q[kind].req.type == ORDER_TYPE_BUY ? SymbolInfoDouble(m_sym, SYMBOL_ASK) : SymbolInfoDouble(m_sym, SYMBOL_BID))
                            : m_q[kind].req.price;
      bool sent = OrderSend(m_q[kind].req, res);
      uint rc = res.retcode;
      if(sent && Accepted(rc))
        {
         m_errors = 0;
         m_q[kind].active = false;
         return true;
        }
      m_errors++;
      m_log.Add("loi_gui_lenh", "Không " + KindName(kind) + " được: mã " + (string)rc + " " + res.comment + " (lần " + (string)(m_q[kind].attempt + 1) + ")");
      if(m_errors >= 5)
        {
         m_coolUntil = GetTickCount64() + 30000;
         m_log.Add("ngat_tam", "5 lỗi gửi lệnh liên tiếp: ngừng gửi 30 giây");
        }
      if(Transient(rc) && m_q[kind].attempt < 4)
        {
         m_q[kind].attempt++;
         m_q[kind].dueMsc = GetTickCount64() + (ulong)MathMin(5000, 200 * (1 << (m_q[kind].attempt - 1)));
         return false;
        }
      m_q[kind].active = false;   // lỗi không tạm thời hoặc hết lượt: bỏ, lần sau engine tự xét lại
      return false;
     }

   // Loại yêu cầu bảo vệ lệnh (dời dừng lỗ, đóng, hủy lệnh chờ) vẫn được gửi khi đang ngắt tạm
   static bool       Protective(int kind) { return kind == RQ_SL || kind == RQ_CLOSE || kind == RQ_FLIP_DEL; }

   bool              Start(int kind, const MqlTradeRequest &req, const string tag)
     {
      EndCooldown();
      if(m_q[kind].active || (CoolingDown() && !Protective(kind)))
         return false;
      m_q[kind].active = true;
      m_q[kind].attempt = 0;
      m_q[kind].sentAt = TimeCurrent();
      m_q[kind].tag = tag;
      m_q[kind].req = req;
      return DoSend(kind);
     }

   void              Base(MqlTradeRequest &r)
     {
      ZeroMemory(r);
      r.symbol = m_sym;
      r.magic = (ulong)m_magic;
      r.type_filling = m_fill;
      r.deviation = m_useDeviation ? 10 : 0;
     }

public:
   double            minDist;       // khoảng cách tối thiểu cho dừng lỗ/lệnh chờ (Stops/Freeze Level)
   double            volMin;
   double            volStep;
   string            specText;

   bool              Init(const string sym, long magic, CJournal *log, string &why)
     {
      m_sym = sym;
      m_magic = magic;
      m_log = log;
      m_errors = 0;
      m_coolUntil = 0;
      for(int k = 0; k < RQ_COUNT; k++)
         m_q[k].active = false;
      m_tick = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
      m_digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
      m_point = SymbolInfoDouble(sym, SYMBOL_POINT);
      volMin = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
      volStep = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
      long stops = SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL), freeze = SymbolInfoInteger(sym, SYMBOL_TRADE_FREEZE_LEVEL);
      minDist = (double)MathMax(stops, freeze) * m_point;
      long exe = SymbolInfoInteger(sym, SYMBOL_TRADE_EXEMODE);
      m_useDeviation = exe == SYMBOL_TRADE_EXECUTION_INSTANT || exe == SYMBOL_TRADE_EXECUTION_REQUEST;
      long fm = SymbolInfoInteger(sym, SYMBOL_FILLING_MODE);
      m_fill = (fm & SYMBOL_FILLING_FOK) != 0 ? ORDER_FILLING_FOK : ((fm & SYMBOL_FILLING_IOC) != 0 ? ORDER_FILLING_IOC : ORDER_FILLING_RETURN);
      m_orderTime = (SymbolInfoInteger(sym, SYMBOL_EXPIRATION_MODE) & SYMBOL_EXPIRATION_GTC) != 0 ? ORDER_TIME_GTC : ORDER_TIME_DAY;
      specText = StringFormat("%s: kiểu khớp %d, chữ số %d, bước giá %.5f, lot nhỏ nhất %.2f, bước lot %.2f, Stops %d, Freeze %d, "
                              "kiểu điền %d, hạn lệnh chờ %d", sym, (int)exe, m_digits, m_tick, volMin, volStep,
                              (int)stops, (int)freeze, (int)m_fill, (int)m_orderTime);
      m_log.Add("thong_so_san", specText);
      return true;
     }

   // Kiểu tài khoản chỉ đọc đúng sau khi terminal đã đăng nhập sàn (gọi lúc đối chiếu, không gọi ở OnInit)
   bool              HedgingOk(void) const { return AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING; }

   // Bỏ một yêu cầu đang chờ thử lại (ví dụ lệnh mở khi bot vừa bị chặn vào lệnh)
   void              Cancel(int kind) { m_q[kind].active = false; }

   double            Norm(double p) const { return NormalizeDouble(MathRound(p / m_tick) * m_tick, m_digits); }
   double            NormVol(double v) const { return MathMax(volMin, MathRound(v / volStep) * volStep); }
   bool              Busy(int kind) const { return m_q[kind].active; }
   bool              AnyBusy(void) const
     {
      for(int k = 0; k < RQ_COUNT; k++)
         if(m_q[k].active)
            return true;
      return false;
     }
   bool              CoolingDown(void) const { return GetTickCount64() < m_coolUntil; }

   // Hết thời gian ngắt tạm thì đếm lỗi lại từ đầu
   void              EndCooldown(void)
     {
      if(m_coolUntil > 0 && GetTickCount64() >= m_coolUntil)
        {
         m_coolUntil = 0;
         m_errors = 0;
        }
     }
   string            Tag(int kind) const { return m_q[kind].tag; }

   // Thử lại các yêu cầu tới hạn. Lệnh mở/lệnh chờ đảo: xác minh trước, nếu đã có trên sàn thì coi như xong.
   void              Process(void)
     {
      EndCooldown();
      ulong now = GetTickCount64();
      for(int k = 0; k < RQ_COUNT; k++)
        {
         if(!m_q[k].active || now < m_q[k].dueMsc || (CoolingDown() && !Protective(k)))
            continue;
         if((k == RQ_OPEN || k == RQ_FLIP_PLACE) && AlreadyDone(m_q[k]))
           {
            m_log.Add("xac_minh", "Yêu cầu " + KindName(k) + " trước đã tới sàn: không gửi lại");
            m_q[k].active = false;
            continue;
           }
         DoSend(k);
        }
     }

   // tp = 0: không đặt chốt lời trên sàn (BotVang)
   bool              Open(int dir, double lot, double sl, const string tag, double tp = 0.0)
     {
      MqlTradeRequest r;
      Base(r);
      r.action = TRADE_ACTION_DEAL;
      r.type = dir > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      r.volume = NormVol(lot);
      r.sl = Norm(sl);
      r.tp = Norm(tp);
      r.comment = tag;
      return Start(RQ_OPEN, r, tag);
     }

   bool              ModifySL(ulong posTicket, double sl)
     {
      MqlTradeRequest r;
      Base(r);
      r.action = TRADE_ACTION_SLTP;
      r.position = posTicket;
      r.sl = Norm(sl);
      r.tp = 0.0;
      return Start(RQ_SL, r, "");
     }

   bool              Close(ulong posTicket, int dir, double volume)
     {
      MqlTradeRequest r;
      Base(r);
      r.action = TRADE_ACTION_DEAL;
      r.position = posTicket;
      r.type = dir > 0 ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
      r.volume = volume;
      return Start(RQ_CLOSE, r, "");
     }

   bool              PlaceStop(int dir, double lot, double price, double sl, const string tag)
     {
      MqlTradeRequest r;
      Base(r);
      r.action = TRADE_ACTION_PENDING;
      r.type = dir > 0 ? ORDER_TYPE_BUY_STOP : ORDER_TYPE_SELL_STOP;
      r.volume = NormVol(lot);
      r.price = Norm(price);
      r.sl = Norm(sl);
      r.type_time = m_orderTime;
      r.comment = tag;
      return Start(RQ_FLIP_PLACE, r, tag);
     }

   bool              ModifyOrder(ulong ticket, double price, double sl)
     {
      MqlTradeRequest r;
      Base(r);
      r.action = TRADE_ACTION_MODIFY;
      r.order = ticket;
      r.price = Norm(price);
      r.sl = Norm(sl);
      r.type_time = m_orderTime;
      return Start(RQ_FLIP_MOD, r, "");
     }

   bool              Delete(ulong ticket)
     {
      MqlTradeRequest r;
      Base(r);
      r.action = TRADE_ACTION_REMOVE;
      r.order = ticket;
      return Start(RQ_FLIP_DEL, r, "");
     }

   // Lệnh (vị thế) và lệnh chờ của bot trên sàn
   int               Positions(ulong &tickets[])
     {
      ArrayResize(tickets, 0);
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong t = PositionGetTicket(i);
         if(t != 0 && PositionGetInteger(POSITION_MAGIC) == m_magic && PositionGetString(POSITION_SYMBOL) == m_sym)
           {
            int n = ArraySize(tickets);
            ArrayResize(tickets, n + 1);
            tickets[n] = t;
           }
        }
      return ArraySize(tickets);
     }

   int               Orders(ulong &tickets[])
     {
      ArrayResize(tickets, 0);
      for(int i = OrdersTotal() - 1; i >= 0; i--)
        {
         ulong t = OrderGetTicket(i);
         if(t != 0 && OrderGetInteger(ORDER_MAGIC) == m_magic && OrderGetString(ORDER_SYMBOL) == m_sym)
           {
            int n = ArraySize(tickets);
            ArrayResize(tickets, n + 1);
            tickets[n] = t;
           }
        }
      return ArraySize(tickets);
     }
  };

#endif
