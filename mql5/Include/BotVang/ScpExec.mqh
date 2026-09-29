// ScpExec.mqh — một nơi duy nhất gửi lệnh, khóa ý định trước khi gửi và đối soát sau khi gửi.
// Nguồn luật: docs/SPEC.md mục 9.5, 12, 14.8. Không gửi khi chưa có kế hoạch đã qua kiểm.
#ifndef SCP_EXEC_MQH
#define SCP_EXEC_MQH

#include <Trade\Trade.mqh>
#include "ScpTypes.mqh"
#include "ScpPlan.mqh"
#include "ScpState.mqh"

class ScpExec
  {
private:
   ScpState         *m_st;
   CTrade            m_trade;
   long              m_magic;
   string            m_symbol;
   long              m_plan_id;
   ENUM_SCP_EXEC_STATE m_state;
   datetime          m_sent_at;
   ulong             m_order_ticket;
   int               m_dir;
   double            m_volume, m_sl, m_tp, m_entry;
   string            m_lease;
   ulong             m_sent_us;
   bool              AcquireLease()
     {
      if(!GlobalVariableCheck(m_lease) && !GlobalVariableTemp(m_lease)) return false;
      double owner=GlobalVariableGet(m_lease);
      double mine=(double)ChartID();
      if(owner==mine) return true;
      if(owner!=0)
         for(long c=ChartFirst();c>=0;c=ChartNext(c))
            if((double)c==owner) return false;
      return GlobalVariableSetOnCondition(m_lease,mine,owner);
     }

   bool              SaveIntent(ScpPlan &p)
     {
      m_plan_id = (long)m_st.Get(SK_SEQ, 0) + 1;
      p.plan_id=m_plan_id;
      m_st.Set(SK_SEQ, (double)m_plan_id);
      m_dir = p.direction;
      m_volume = p.volume;
      m_sl = p.sl;
      m_tp = p.tp;
      m_entry = (p.direction > 0) ? SymbolInfoDouble(m_symbol, SYMBOL_ASK) : SymbolInfoDouble(m_symbol, SYMBOL_BID);
      m_sent_at = TimeCurrent();
      m_sent_us=GetMicrosecondCount();
      m_state = SCP_EX_SENT_UNKNOWN;
      m_st.Set(SK_PLAN_ID, (double)m_plan_id);
      m_st.Set(SK_EXEC_STATE, (double)m_state);
      m_st.Set(SK_POS_DIR, (double)p.direction);
      m_st.Set(SK_POS_VOL, p.volume);
      m_st.Set(SK_POS_SL, p.sl);
      m_st.Set(SK_POS_TP, p.tp);
      m_st.Set(SK_POS_ENTRY, m_entry);
      m_st.Set(SK_POS_OPEN, (double)m_sent_at);
      m_st.Set(SK_POS_HOLD, 0.0);
      m_st.Set(SK_POS_PROG, 0.0);
      m_st.Set(SK_POS_ATR, p.atr_m1);
      m_st.Set(SK_RISK_BUDGET, p.risk_budget);
      m_st.Set(SK_RISK_COST, p.expected_cost);
      m_st.Set(SK_HOLD_SEC, 0.0);
      m_st.Set(SK_PROG_SEC, 0.0);
      m_st.Set(SK_ORDER, 0);
      m_st.Set(SK_POS_MFE, 0.0);
      m_st.Set(SK_POS_INVAL, p.invalidation);
      m_st.Set(SK_POS_R0, MathAbs(m_entry - p.sl));
      m_st.Set(SK_POS_TGT, p.target_edge_bid);
      m_st.Set(SK_SCALE_STATE,0);
      m_st.Set(SK_SCALE_VOL,p.partial_volume);
      m_st.Set(SK_SCALE_AT,p.partial_trigger);
      m_st.Set(SK_BE_AT,p.breakeven_trigger);
      m_st.Flush();
      return m_st.Healthy();
     }

public:
                     ScpExec()
     {
      m_st = NULL;
      m_magic = 0;
      m_plan_id = 0;
      m_state = SCP_EX_IDLE;
      m_sent_at = 0;
      m_order_ticket = 0;
      m_sent_us=0;
      m_dir = 0;
      m_volume = m_sl = m_tp = m_entry = 0.0;
     }

   void              Init(ScpState *st, long magic, const string sym)
     {
      m_st = st;
      m_magic = magic;
      m_symbol = sym;
      uint hash=2166136261;
      string scope=AccountInfoString(ACCOUNT_SERVER)+":"+sym;
      for(int i=0;i<StringLen(scope);i++) hash=(hash^(uint)StringGetCharacter(scope,i))*16777619;
      m_lease="SCP_LEASE_"+(string)AccountInfoInteger(ACCOUNT_LOGIN)+"_"+(string)hash;
      m_trade.SetExpertMagicNumber(magic);
      m_trade.SetTypeFillingBySymbol(sym);
      m_trade.SetDeviationInPoints(20);
      // Nhận lại ý định đang dở sau khởi động lại (SPEC 12).
      m_plan_id = (long)m_st.Get(SK_PLAN_ID, 0.0);
      m_state = (ENUM_SCP_EXEC_STATE)(int)m_st.Get(SK_EXEC_STATE, 0.0);
      m_sent_at = (datetime)m_st.Get(SK_POS_OPEN, 0.0);
      m_dir = (int)m_st.Get(SK_POS_DIR, 0.0);
      m_volume = m_st.Get(SK_POS_VOL, 0.0);
      m_sl = m_st.Get(SK_POS_SL, 0.0);
      m_tp = m_st.Get(SK_POS_TP, 0.0);
      m_entry = m_st.Get(SK_POS_ENTRY, 0.0);
      m_order_ticket = (ulong)m_st.Get(SK_ORDER, 0.0);
     }

   ENUM_SCP_EXEC_STATE State() { return m_state; }
   long              PlanId() { return m_plan_id; }
   bool              HasPlan() { return m_plan_id>0 && m_st.Get(SK_POS_ATR)>0 && m_st.Get(SK_RISK_BUDGET)>0; }
   void              ReleaseLease()
     {
      if(ScpCanStart(m_state) && !HasOurPosition() && !HasOurPendingOrder() && GlobalVariableCheck(m_lease))
         GlobalVariableSetOnCondition(m_lease,0,(double)ChartID());
     }

   void              OnTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request,
                                    const MqlTradeResult &result)
     {
      if(trans.type==TRADE_TRANSACTION_DEAL_ADD && trans.deal>0 && m_sent_us>0 && HistoryDealSelect(trans.deal))
         if(HistoryDealGetInteger(trans.deal,DEAL_MAGIC)==m_magic &&
            HistoryDealGetString(trans.deal,DEAL_SYMBOL)==m_symbol &&
            (ulong)HistoryDealGetInteger(trans.deal,DEAL_ORDER)==m_order_ticket &&
            HistoryDealGetInteger(trans.deal,DEAL_ENTRY)==DEAL_ENTRY_IN)
            Print("[SCP][EXEC_LATENCY] plan=",m_plan_id," local_fill_event_us=",GetMicrosecondCount()-m_sent_us);
      if(trans.type!=TRADE_TRANSACTION_REQUEST || request.magic!=m_magic || request.symbol!=m_symbol ||
         request.comment!="SCP:"+(string)m_plan_id || m_plan_id<=0) return;
      if(result.order>0)
        { m_order_ticket=result.order; m_st.Set(SK_ORDER,(double)m_order_ticket); m_st.Flush(); }
     }
   bool              Busy() { return (m_state != SCP_EX_IDLE && m_state != SCP_EX_CLOSED && m_state != SCP_EX_REJECTED); }

   // Vị thế của bot, nếu có.
   bool              FindOurPosition(ulong &ticket, double &volume, double &open_price, int &dir,
                                     double &sl, double &tp, datetime &opened)
     {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong t = PositionGetTicket(i);
         if(t == 0)
            continue;
         if(PositionGetString(POSITION_SYMBOL) != m_symbol)
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != m_magic)
            continue;
         ticket = t;
         volume = PositionGetDouble(POSITION_VOLUME);
         open_price = PositionGetDouble(POSITION_PRICE_OPEN);
         dir = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? +1 : -1;
         sl = PositionGetDouble(POSITION_SL);
         tp = PositionGetDouble(POSITION_TP);
         opened = (datetime)PositionGetInteger(POSITION_TIME);
         return true;
        }
      return false;
     }

   bool              HasOurPosition() { ulong t; double v, o, s, p; int d; datetime w; return FindOurPosition(t, v, o, d, s, p, w); }

   // Có lệnh/vị thế của người khác trên cùng ký hiệu: không mở mới, không đụng vào (SPEC 12).
   bool              HasForeignExposure()
     {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong t = PositionGetTicket(i);
         if(t == 0)
            continue;
         if(PositionGetString(POSITION_SYMBOL) != m_symbol)
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != m_magic)
            return true;
        }
      for(int i = OrdersTotal() - 1; i >= 0; i--)
        {
         ulong t = OrderGetTicket(i);
         if(t == 0)
            continue;
         if(OrderGetString(ORDER_SYMBOL) != m_symbol)
            continue;
         if(OrderGetInteger(ORDER_MAGIC) != m_magic)
            return true;
        }
      return false;
     }

   bool              HasOurPendingOrder()
     {
      for(int i = OrdersTotal() - 1; i >= 0; i--)
        {
         ulong t = OrderGetTicket(i);
         if(t == 0)
            continue;
         if(OrderGetString(ORDER_SYMBOL) != m_symbol)
            continue;
         if(OrderGetInteger(ORDER_MAGIC) == m_magic)
            return true;
        }
      return false;
     }

   // Gửi một lần theo kế hoạch đã kiểm. Chỉ gửi khi đang rảnh và không có vị thế/lệnh của bot.
   bool              Send(ScpPlan &p, string &why)
     {
      why = "";
      if(!AcquireLease()) { why="ký hiệu đã có EA khác giữ quyền gửi"; return false; }
      if(!ScpCanStart(m_state))
        {
         why = "đang có kế hoạch chưa kết thúc (" + IntegerToString((int)m_state) + ")";
         return false;
        }
      if(HasOurPosition() || HasOurPendingOrder())
        {
         why = "đã có vị thế hoặc lệnh của bot";
         return false;
        }
      if(HasForeignExposure()) { why="có lệnh không thuộc bot"; return false; }
      if(!MQLInfoInteger(MQL_TESTER) && AccountInfoInteger(ACCOUNT_TRADE_MODE)!=ACCOUNT_TRADE_MODE_DEMO)
        { why="tiền thật chưa được hỗ trợ"; return false; }
      if(!m_st.Healthy() || !SaveIntent(p)) { why = "không lưu được ý định, khóa gửi"; return false; }
      double price = 0.0;
      bool ok = false;
      if(p.direction > 0)
         ok = m_trade.Buy(p.volume, m_symbol, price, p.sl, p.tp, "SCP:"+(string)m_plan_id);
      else
         ok = m_trade.Sell(p.volume, m_symbol, price, p.sl, p.tp, "SCP:"+(string)m_plan_id);
      uint rc = m_trade.ResultRetcode();
      m_order_ticket = m_trade.ResultOrder();
      m_st.Set(SK_ORDER, (double)m_order_ticket);
      if(!ok || (rc != TRADE_RETCODE_DONE && rc != TRADE_RETCODE_DONE_PARTIAL && rc != TRADE_RETCODE_PLACED))
        {
         if(rc == TRADE_RETCODE_TIMEOUT || rc == TRADE_RETCODE_CONNECTION || rc == TRADE_RETCODE_ERROR || rc == 0)
           {
            // Không rõ kết quả: giữ SENT_UNKNOWN, chờ đối soát, không gửi lại.
            m_state = SCP_EX_SENT_UNKNOWN;
            m_st.Set(SK_EXEC_STATE, (double)m_state);
            m_st.Flush();
            why = "kết quả gửi chưa rõ (retcode " + IntegerToString((int)rc) + "), chờ đối soát";
            return false;
           }
         m_state = SCP_EX_REJECTED;
         m_st.Set(SK_EXEC_STATE, (double)m_state);
         why = "sàn từ chối: " + IntegerToString((int)rc) + " " + m_trade.ResultRetcodeDescription();
         ClearPlan();
         return false;
        }
      m_state = SCP_EX_PARTIAL;
      m_st.Set(SK_EXEC_STATE, (double)m_state);
      m_st.Flush();
      why = "đã gửi, chờ xác nhận khớp";
      return true;
     }

   // Đối soát với sàn sau khi gửi hoặc sau khi khởi động lại (SPEC 9.5).
   void              Reconcile(string &note)
     {
      note = "";
      if(ScpCanStart(m_state) && !HasOurPosition()) return;
      ulong ticket; double vol, open_price, sl, tp; int dir; datetime opened;
      bool have = FindOurPosition(ticket, vol, open_price, dir, sl, tp, opened);
      if(have)
        {
         if(!HasPlan() || m_dir != dir)
           { note = "thiếu kế hoạch khôi phục, khóa mở mới"; m_state = SCP_EX_SENT_UNKNOWN; return; }
         m_st.Set(SK_POS_HOLD, 0.0);
         m_st.Set(SK_POS_PROG, 0.0);
         double actual_loss = 0;
         if(sl <= 0 || !OrderCalcProfit(dir > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
                                       m_symbol, vol, open_price, sl, actual_loss) ||
            MathMax(0.0, -actual_loss) + m_st.Get(SK_RISK_COST) > m_st.Get(SK_RISK_BUDGET) + 0.01)
           { CloseOurPosition(note); note = "thiếu bảo vệ/vượt tiền chịu lỗ; " + note; return; }
         m_state = (vol + 1e-9 < m_volume) ? SCP_EX_PARTIAL : SCP_EX_FILLED;
         m_st.Set(SK_EXEC_STATE, (double)m_state);
         m_st.Set(SK_POS_ID, (double)ticket);
         if(PositionSelectByTicket(ticket)) m_st.Set(SK_POS_IDENT,(double)PositionGetInteger(POSITION_IDENTIFIER));
         // Thiếu bảo vệ: đặt lại SL/TP theo kế hoạch; nếu không đặt được thì đóng an toàn.
         if(sl == 0.0 || tp == 0.0)
           {
            double use_sl = (sl != 0.0) ? sl : m_sl;
            double use_tp = (tp != 0.0) ? tp : m_tp;
            if(!ModifyProtection(ticket, use_sl, use_tp, note))
              {
               note = "không đặt được dừng/chốt, yêu cầu đóng an toàn";
               CloseOurPosition(note);
              }
            else
               note = "đã bổ sung dừng/chốt còn thiếu";
           }
         m_st.Flush();
         return;
        }
      if(HasOurPendingOrder())
        {
         note = "đang có lệnh chờ của bot";
         return;
        }
      // Chỉ kết luận từ đúng order đã lưu; mất kết nối/không thấy không phải từ chối.
      if(m_order_ticket > 0 && HistoryOrderSelect(m_order_ticket))
        {
         ENUM_ORDER_STATE st = (ENUM_ORDER_STATE)HistoryOrderGetInteger(m_order_ticket, ORDER_STATE);
         bool closed_deal=false;
         long pid=HistoryOrderGetInteger(m_order_ticket,ORDER_POSITION_ID);
         if(pid>0 && HistorySelectByPosition((ulong)pid))
           {
            double remaining=0;
            for(int i=0;i<HistoryDealsTotal();i++)
              {
               ulong d=HistoryDealGetTicket(i);
               long e=HistoryDealGetInteger(d,DEAL_ENTRY);
               if(e==DEAL_ENTRY_IN) remaining+=HistoryDealGetDouble(d,DEAL_VOLUME);
               if(e==DEAL_ENTRY_OUT || e==DEAL_ENTRY_OUT_BY)
                 { remaining-=HistoryDealGetDouble(d,DEAL_VOLUME); closed_deal=true; }
              }
            closed_deal=closed_deal && remaining<=1e-8;
           }
         if((st == ORDER_STATE_FILLED && closed_deal) ||
            ((pid==0 || closed_deal) && (st == ORDER_STATE_CANCELED || st == ORDER_STATE_REJECTED || st == ORDER_STATE_EXPIRED)))
           {
            m_state = st == ORDER_STATE_FILLED ? SCP_EX_CLOSED : SCP_EX_REJECTED;
            m_st.Set(SK_LAST_CLOSE, (double)TimeCurrent());
            note = "đã đối soát order kết thúc và không còn vị thế";
            ClearPlan();
            return;
           }
        }
      note = "chưa rõ kết quả, giữ khóa để đối soát; không tự hết hạn";
     }

   bool              ModifyProtection(ulong ticket, double sl, double tp, string &why)
     {
      if(!m_trade.PositionModify(ticket, sl, tp) ||
         (m_trade.ResultRetcode() != TRADE_RETCODE_DONE && m_trade.ResultRetcode() != TRADE_RETCODE_NO_CHANGES))
        { why = "sàn chưa nhận sửa bảo vệ: " + m_trade.ResultRetcodeDescription(); return false; }
      double tick = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
      if(!PositionSelectByTicket(ticket) || MathAbs(PositionGetDouble(POSITION_SL) - sl) > tick / 2 ||
         MathAbs(PositionGetDouble(POSITION_TP) - tp) > tick / 2)
        { why = "chưa đọc lại đúng dừng/chốt từ sàn"; return false; }
      return true;
     }

   // Một ý định chốt phần mỗi vị thế; chưa rõ thì giữ khóa, kể cả sau khởi động lại.
   int               PartialOnce(string &why)
     {
      why="";
      int stage=(int)m_st.Get(SK_SCALE_STATE);
      if(stage>=2) return 0;
      ulong ticket; double vol,entry,sl,tp; int dir; datetime opened;
      if(!FindOurPosition(ticket,vol,entry,dir,sl,tp,opened) || !HasPlan()) return 0;
      double part=m_st.Get(SK_SCALE_VOL),step=SymbolInfoDouble(m_symbol,SYMBOL_VOLUME_STEP);
      double minimum=SymbolInfoDouble(m_symbol,SYMBOL_VOLUME_MIN);
      if(part<=0) return 0;
      if(stage==1)
        {
         if(vol<m_volume-step*0.5)
           { m_st.Set(SK_SCALE_STATE,2); m_st.Flush(); why="đã khớp chốt phần; còn "+DoubleToString(vol,4)+" lot"; return 2; }
         why="chốt phần chưa rõ kết quả, không gửi lại"; return 1;
        }
      if(AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING ||
         MathAbs(vol-m_volume)>step*0.5 || part<minimum || vol-part<minimum-1e-9)
        { m_st.Set(SK_SCALE_STATE,3); m_st.Flush(); why="không chia được vị thế theo kế hoạch/tài khoản"; return -1; }
      m_st.Set(SK_SCALE_STATE,1); m_st.Flush();
      if(!m_st.Healthy()) { why="không lưu được ý định chốt phần"; return -1; }
      bool ok=m_trade.PositionClosePartial(ticket,part);
      uint rc=m_trade.ResultRetcode();
      if(!ok || (rc!=TRADE_RETCODE_DONE && rc!=TRADE_RETCODE_DONE_PARTIAL && rc!=TRADE_RETCODE_PLACED))
        {
         if(rc!=TRADE_RETCODE_TIMEOUT && rc!=TRADE_RETCODE_CONNECTION && rc!=TRADE_RETCODE_ERROR && rc!=0)
            m_st.Set(SK_SCALE_STATE,3);
         m_st.Flush(); why="chốt phần chưa xác nhận: "+m_trade.ResultRetcodeDescription(); return -1;
        }
      if(PositionSelectByTicket(ticket) && PositionGetDouble(POSITION_VOLUME)<m_volume-step*0.5)
        { m_st.Set(SK_SCALE_STATE,2); m_st.Flush(); why="đã khớp chốt "+DoubleToString(m_volume-PositionGetDouble(POSITION_VOLUME),4)+" lot"; return 2; }
      why="đã yêu cầu chốt phần, chờ đối soát"; return 1;
     }

   bool              CloseOurPosition(string &why)
     {
      ulong ticket; double vol, open_price, sl, tp; int dir; datetime opened;
      if(!FindOurPosition(ticket, vol, open_price, dir, sl, tp, opened))
        {
         why = "không có vị thế của bot để đóng";
         return false;
        }
      m_state = SCP_EX_CLOSE_REQUESTED;
      m_st.Set(SK_EXEC_STATE, (double)m_state);
      m_st.Flush();
      if(!m_trade.PositionClose(ticket) ||
         (m_trade.ResultRetcode() != TRADE_RETCODE_DONE && m_trade.ResultRetcode() != TRADE_RETCODE_DONE_PARTIAL))
        {
         why = "yêu cầu đóng chưa được xác nhận: " + m_trade.ResultRetcodeDescription();
         return false;
        }
      // Chỉ coi là đã đóng sau khi sàn xác nhận bằng việc vị thế không còn.
      if(!HasOurPosition())
        {
         m_state = SCP_EX_CLOSED;
         m_st.Set(SK_LAST_CLOSE,(double)TimeCurrent());
         m_st.Set(SK_EXEC_STATE, (double)m_state);
         ClearPlan();
         why = "đã đóng";
         return true;
        }
      why = "sàn chưa xác nhận đóng";
      return false;
     }

   void              ClearPlan()
     {
      m_plan_id = 0;
      m_dir = 0;
      m_volume = m_sl = m_tp = m_entry = 0.0;
      m_sent_at = 0;
      m_order_ticket = 0;
      if(m_st != NULL)
        {
         m_st.Set(SK_PLAN_ID, 0.0);
         m_st.Set(SK_EXEC_STATE, (double)m_state);
         m_st.Set(SK_POS_ID, 0.0);
         m_st.Flush();
        }
     }
  };

#endif // SCP_EXEC_MQH
