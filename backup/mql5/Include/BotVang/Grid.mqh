// Thang lệnh chờ hai phía của BotLuoi: rải thang, đếm lệnh của rổ, đóng cả rổ.
// Chỉ đụng lệnh đúng Magic + Symbol. Lot cố định, không dừng lỗ, không chốt lời từng lệnh.
#ifndef BOTVANG_GRID_MQH
#define BOTVANG_GRID_MQH

#define GRID_TAG "BotLuoi"

class CGrid
  {
private:
   string            m_sym;
   long              m_magic;
   double            m_step;
   int               m_levels;
   double            m_lot;
   double            m_tick;
   int               m_digits;
   ENUM_ORDER_TYPE_FILLING m_fill;
   ENUM_ORDER_TYPE_TIME m_orderTime;
   ulong             m_orders[];   // mã các lệnh chờ của rổ đang chạy (= mã lệnh mở ra khi khớp, tài khoản hedging)

   double            Norm(double p) const { return NormalizeDouble(MathRound(p / m_tick) * m_tick, m_digits); }

   static bool       Accepted(uint rc) { return rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_PLACED || rc == TRADE_RETCODE_DONE_PARTIAL; }

   // Gửi một yêu cầu; order = mã lệnh sàn cấp (lệnh chờ: cũng là mã của lệnh mở ra khi khớp)
   bool              Send(MqlTradeRequest &r, string &err, ulong &order)
     {
      MqlTradeResult res;
      ZeroMemory(res);
      bool sent = OrderSend(r, res);
      order = res.order;
      if(sent && Accepted(res.retcode))
         return true;
      err = "mã " + (string)res.retcode + " " + res.comment;
      return false;
     }

   bool              Pending(ENUM_ORDER_TYPE type, double price, string &err)
     {
      ulong order;
      MqlTradeRequest r;
      ZeroMemory(r);
      r.action = TRADE_ACTION_PENDING;
      r.symbol = m_sym;
      r.magic = (ulong)m_magic;
      r.type = type;
      r.volume = m_lot;
      r.price = Norm(price);
      r.type_filling = m_fill;
      r.type_time = m_orderTime;
      r.comment = GRID_TAG;
      if(!Send(r, err, order))
         return false;
      int n = ArraySize(m_orders);
      ArrayResize(m_orders, n + 1, 32);
      m_orders[n] = order;
      return true;
     }

   bool              OfBasket(long positionId) const
     {
      for(int i = 0; i < ArraySize(m_orders); i++)
         if((long)m_orders[i] == positionId)
            return true;
      return false;
     }

   bool              Mine(ulong positionTicket) { return positionTicket != 0 && PositionGetInteger(POSITION_MAGIC) == m_magic && PositionGetString(POSITION_SYMBOL) == m_sym; }

   // Đóng một lệnh đang mở (đã chọn bằng PositionGetTicket) theo giá hiện tại
   bool              ClosePosition(ulong tk, string &err)
     {
      MqlTick t;
      SymbolInfoTick(m_sym, t);
      bool buy = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
      MqlTradeRequest r;
      ZeroMemory(r);
      r.action = TRADE_ACTION_DEAL;
      r.symbol = m_sym;
      r.magic = (ulong)m_magic;
      r.position = tk;
      r.type = buy ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
      r.volume = PositionGetDouble(POSITION_VOLUME);
      r.price = buy ? t.bid : t.ask;
      r.deviation = 1000;
      r.type_filling = m_fill;
      r.comment = GRID_TAG;
      ulong order;
      return Send(r, err, order);
     }

public:
   int               rejects;     // số lần sàn từ chối yêu cầu
   string            lastError;
   int               lastClosed;  // số lệnh đang mở mà lần CloseAll gần nhất đóng được

   bool              Init(const string sym, long magic, double step, int levels, double lot, string &why)
     {
      m_sym = sym;
      m_magic = magic;
      m_step = step;
      m_levels = levels;
      m_lot = lot;
      rejects = 0;
      lastError = "";
      lastClosed = 0;
      m_tick = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
      m_digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
      long fm = SymbolInfoInteger(sym, SYMBOL_FILLING_MODE);
      m_fill = (fm & SYMBOL_FILLING_FOK) != 0 ? ORDER_FILLING_FOK : ((fm & SYMBOL_FILLING_IOC) != 0 ? ORDER_FILLING_IOC : ORDER_FILLING_RETURN);
      m_orderTime = (SymbolInfoInteger(sym, SYMBOL_EXPIRATION_MODE) & SYMBOL_EXPIRATION_GTC) != 0 ? ORDER_TIME_GTC : ORDER_TIME_DAY;
      double minDist = (double)MathMax(SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL), SymbolInfoInteger(sym, SYMBOL_TRADE_FREEZE_LEVEL))
                       * SymbolInfoDouble(sym, SYMBOL_POINT);
      if(step <= minDist || step < m_tick)
        {
         why = "bước " + DoubleToString(step, m_digits) + " nhỏ hơn khoảng cách tối thiểu của sàn";
         return false;
        }
      return true;
     }

   // Kiểu tài khoản chỉ đọc đúng sau khi terminal đã đăng nhập sàn (gọi ở tick đầu, không gọi ở OnInit)
   static bool       HedgingOk(void) { return AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING; }

   // Rải thang quanh Ask/Bid của tick t: MUA chờ tại Ask + k × bước, BÁN chờ tại Bid − k × bước, k = 1…levels.
   // Ghi lại mã các lệnh chờ của rổ mới. Sàn từ chối một lệnh thì dừng ngay (thang đằng nào cũng bị gỡ).
   // Trả về số lệnh chờ đặt được.
   int               Build(const MqlTick &t)
     {
      ArrayResize(m_orders, 0);
      int placed = 0;
      string err;
      for(int k = 1; k <= m_levels; k++)
        {
         if(!Pending(ORDER_TYPE_BUY_STOP, t.ask + k * m_step, err) || !Pending(ORDER_TYPE_SELL_STOP, t.bid - k * m_step, err))
           {
            rejects++;
            lastError = err;
            return ArraySize(m_orders);
           }
         placed += 2;
        }
      return placed;
     }

   // Đếm lệnh của bot: số MUA, số BÁN đang mở của rổ đang chạy, tổng lời/lỗ của chúng (gồm phí qua đêm), số lệnh chờ,
   // và số lệnh "sót" (lệnh của bot không thuộc rổ đang chạy, ví dụ lệnh chờ của rổ trước khớp muộn lúc đang hủy)
   void              Count(int &buys, int &sells, int &pending, double &profit, int &strays)
     {
      buys = 0;
      sells = 0;
      pending = 0;
      profit = 0.0;
      strays = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong tk = PositionGetTicket(i);
         if(!Mine(tk))
            continue;
         if(!OfBasket(PositionGetInteger(POSITION_IDENTIFIER)))
           {
            strays++;
            continue;
           }
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            buys++;
         else
            sells++;
         profit += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
        }
      for(int i = OrdersTotal() - 1; i >= 0; i--)
        {
         ulong tk = OrderGetTicket(i);
         if(tk != 0 && OrderGetInteger(ORDER_MAGIC) == m_magic && OrderGetString(ORDER_SYMBOL) == m_sym)
            pending++;
        }
     }

   // Đóng các lệnh "sót" (không thuộc rổ đang chạy). Trả về số lệnh đóng được.
   int               CloseStrays(void)
     {
      int n = 0;
      string err;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong tk = PositionGetTicket(i);
         if(!Mine(tk) || OfBasket(PositionGetInteger(POSITION_IDENTIFIER)))
            continue;
         if(ClosePosition(tk, err))
            n++;
         else
           {
            rejects++;
            lastError = err;
           }
        }
      return n;
     }

   // Hủy mọi lệnh chờ (gần giá trước, vì chúng dễ khớp nhất), rồi đóng mọi lệnh đang mở của bot.
   // Trả về true nếu sàn nhận hết các yêu cầu; lastClosed = số lệnh đang mở đóng được.
   bool              CloseAll(void)
     {
      bool ok = true;
      string err;
      MqlTick t;
      SymbolInfoTick(m_sym, t);
      double mid = (t.bid + t.ask) / 2.0;
      ulong tickets[];
      double dist[];
      for(int i = OrdersTotal() - 1; i >= 0; i--)
        {
         ulong tk = OrderGetTicket(i);
         if(tk == 0 || OrderGetInteger(ORDER_MAGIC) != m_magic || OrderGetString(ORDER_SYMBOL) != m_sym)
            continue;
         int n = ArraySize(tickets);
         ArrayResize(tickets, n + 1, 32);
         ArrayResize(dist, n + 1, 32);
         tickets[n] = tk;
         dist[n] = MathAbs(OrderGetDouble(ORDER_PRICE_OPEN) - mid);
        }
      for(int a = 0; a < ArraySize(tickets); a++)
        {
         int best = a;
         for(int b = a + 1; b < ArraySize(tickets); b++)
            if(dist[b] < dist[best])
               best = b;
         ulong tk = tickets[best];
         tickets[best] = tickets[a];
         tickets[a] = tk;
         double dd = dist[best];
         dist[best] = dist[a];
         dist[a] = dd;
         MqlTradeRequest r;
         ZeroMemory(r);
         r.action = TRADE_ACTION_REMOVE;
         r.order = tk;
         ulong order;
         if(!Send(r, err, order))
           {
            ok = false;
            rejects++;
            lastError = err;
           }
        }
      lastClosed = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong tk = PositionGetTicket(i);
         if(!Mine(tk))
            continue;
         if(ClosePosition(tk, err))
            lastClosed++;
         else
           {
            ok = false;
            rejects++;
            lastError = err;
           }
        }
      return ok;
     }

   // Tiền lời của 1 bước giá với 1 lệnh
   double            StepMoney(double price)
     {
      double m = 0.0;
      if(!OrderCalcProfit(ORDER_TYPE_BUY, m_sym, m_lot, price, price + m_step, m))
         return 0.0;
      return m;
     }

   // Ký quỹ cần cho 1 lệnh (để biết tài khoản còn mở được lệnh không)
   double            MarginOne(double price)
     {
      double m = 0.0;
      if(!OrderCalcMargin(ORDER_TYPE_BUY, m_sym, m_lot, price, m))
         return 0.0;
      return m;
     }
  };

#endif
