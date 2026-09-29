// ScpManage.mqh — quản lý vị thế đang mở theo kịch bản (SPEC mục 11).
// Chỉ siết dừng theo cấu trúc mới, không nới; giữ nguyên chốt lời; không đóng theo tuổi lệnh.
#ifndef SCP_MANAGE_MQH
#define SCP_MANAGE_MQH

#include "ScpTypes.mqh"
#include "ScpSeries.mqh"
#include "ScpReaction.mqh"
#include "ScpExec.mqh"
#include "ScpState.mqh"
#include "ScpZones.mqh"

#define SCP_MG_NONE    0
#define SCP_MG_TIGHTEN 1
#define SCP_MG_CLOSE   2
#define SCP_MG_ERROR   3
#define SCP_MG_PARTIAL 4

bool ScpStrongCounter(const ScpBar &prev,const ScpBar &cur,int held_dir,double lo,double hi,
                       double atr,double eps,double small,datetime opened)
  {
   if(cur.open_time<opened || atr<=0 || small<=0) return false;
   bool touch=(cur.h>=lo && cur.l<=hi) || (prev.open_time>=opened && prev.h>=lo && prev.l<=hi);
   int d=-held_dir;
   bool rejection=ScpP1(cur,d,lo,hi,atr,touch) ||
                  (prev.open_time>=opened && ScpBody(cur)>=0.8*atr && ScpP2(prev,cur,d,lo,hi,touch));
   return rejection && ScpP3(cur,d,small,eps,touch);
  }

// Bảo vệ lời trước khi quay về giá vào: đã bảo vệ, vẫn lời, nến ngược mạnh phá nhịp mới.
bool ScpProfitReversal(const ScpBar &cur,int held_dir,double entry,double current_exit,double sl,
                       double peak,double be_trigger,double protected_price,double atr,double eps,datetime opened)
  {
   if(cur.open_time<opened || be_trigger<=0 || peak<be_trigger || atr<=0 || protected_price<=0 ||
      held_dir*(current_exit-entry)<=0 || held_dir*(sl-entry)<-1e-8 ||
      held_dir*(protected_price-entry)<=0) return false;
   return ScpP4(cur,-held_dir,protected_price,atr,eps);
  }

// Mất mốc vô hiệu: nến M1 đóng sau lúc khớp và đóng qua mốc. Chạm mốc trong nến chưa đủ (SPEC 11.3).
bool ScpInvalidationClosed(const ScpBar &closed,int held_dir,double inval,datetime opened)
  {
   if(inval<=0 || closed.close_time<=opened) return false;
   return held_dir>0 ? closed.c<inval : closed.c>inval;
  }

// Siết theo cấu trúc chỉ sau khi đi thuận trail_r lần khoảng dừng ban đầu; trail_r=0 hoặc thiếu r0 thì như cũ.
bool ScpTrailAllowed(double mfe,double r0,double trail_r)
  {
   return trail_r<=0.0 || r0<=0.0 || mfe>=trail_r*r0;
  }

class ScpManage
  {
private:
   long              m_magic;
   string            m_symbol;
   double            m_buffer_atr;
   double            m_trail_r;

public:
                     ScpManage()
     {
      m_magic = 0;
      m_symbol = "";
      m_buffer_atr = SCP_K_BUFFER;
      m_trail_r = 0.0;
     }

   // trail_r=0: siết theo cấu trúc ngay khi có đỉnh/đáy mới (cách cũ).
   void              Init(long magic, const string sym, double trail_r = 0.0)
     {
      m_magic = magic;
      m_symbol = sym;
      m_trail_r = trail_r;
     }

   // Một bước quản lý. Trả về SCP_MG_*; `note` giải thích.
   int               Step(ScpSeries *m1, ScpExec &exec, ScpState &st, string &note, ScpZoneMap *zones = NULL)
     {
      note = "";
      ulong ticket; double vol, entry, sl, tp; int dir; datetime opened;
      if(!exec.FindOurPosition(ticket, vol, entry, dir, sl, tp, opened))
         return SCP_MG_NONE;
      double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      double exit_now = (dir > 0) ? bid : ask;
      double atr = st.Get(SK_POS_ATR, 0.0);
      double buffer = m_buffer_atr * ((atr > 0.0) ? atr : 0.0);
      if(buffer <= 0.0)
         buffer = 2.0 * SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
      double spread = MathMax(0.0, ask - bid);
      buffer=MathMax(buffer,MathMax(spread,2.0*SymbolInfoDouble(m_symbol,SYMBOL_TRADE_TICK_SIZE)));
      // 1) Theo dõi mức đi thuận lớn nhất và mức đi ngược (SPEC 11.4).
      double mfe = st.Get(SK_POS_MFE, 0.0);
      double cur_mfe = (dir > 0) ? (bid - entry) : (entry - ask);
      if(cur_mfe > mfe)
        {
         mfe = cur_mfe;
         st.Set(SK_POS_MFE, mfe);
        }
      // 2) Mất mốc vô hiệu của kịch bản: nến M1 sau lúc khớp đóng qua mốc (SPEC 11.3).
      //    Chạm mốc trong nến không đủ; dừng sàn (mốc + đệm) lo phần xuyên sâu trong nến.
      double inval = st.Get(SK_POS_INVAL, 0.0);
      if(inval > 0.0 && m1 != NULL && m1.Count() >= 1)
        {
         bool broken = ScpInvalidationClosed(m1.Bar(m1.Count() - 1), dir, inval, opened);
         if(broken)
           {
            string why = "";
            if(exec.CloseOurPosition(why))
              {
               note = "mất mốc vô hiệu " + DoubleToString(inval, 3) + ": " + why;
               return SCP_MG_CLOSE;
              }
            note = "mất mốc vô hiệu nhưng chưa đóng được: " + why;
            return SCP_MG_ERROR;
           }
        }
      // Tuổi lệnh/MFE không tự tạo lý do đóng. Trạng thái hạn giờ lưu từ bản trước bị bỏ qua.
      // 3) Phản ứng ngược có căn cứ trước mục tiêu (SPEC 11.3): dùng nến M1 đã đóng.
      if(m1 != NULL && m1.Count() >= 2)
        {
         ScpBar cur = m1.Bar(m1.Count() - 1);
         ScpBar prev = m1.Bar(m1.Count() - 2);
         double protected_price=0;
         for(int i=m1.PivotCount()-1;i>=0;i--)
           {
            ScpPivot p=m1.Pivot(i);
            if(!p.ambiguous && p.is_high==(dir<0) && p.bar_time>=opened && p.known_at<=cur.open_time)
              { protected_price=p.price; break; }
           }
         if(TimeCurrent()<=cur.known_at+2 &&
            ScpProfitReversal(cur,dir,entry,exit_now,sl,mfe,st.Get(SK_BE_AT,2.5),protected_price,atr,buffer,opened))
           {
            double money=0;
            double initial_volume=st.Get(SK_POS_VOL,vol);
            double costs=initial_volume>0 ? st.Get(SK_RISK_COST)*vol/initial_volume : 0;
            if(OrderCalcProfit(dir>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL,m_symbol,vol,entry,exit_now,money) && money>costs)
              {
               string why="";
               if(exec.CloseOurPosition(why))
                 { note="bảo vệ lời: nến ngược mạnh phá cấu trúc sau khớp; "+why; return SCP_MG_CLOSE; }
               note="chưa đóng được để bảo vệ lời: "+why; return SCP_MG_ERROR;
              }
           }
         double target = st.Get(SK_POS_TGT, 0.0);
         if(zones != NULL)
           {
            long zid; double edge; ENUM_SCP_ROLE role; ENUM_SCP_TF tf;
            if(zones.NearestOpposite(bid,dir,0,zid,edge,role,tf,0,SCP_TF_D1,prev.open_time))
               target=edge;
           }
         if(target > 0.0)
           {
            bool near_target = cur.h>=target-buffer && cur.l<=target+buffer;
            near_target=near_target || (prev.open_time>=opened && prev.h>=target-buffer && prev.l<=target+buffer);
            if(near_target)
              {
               double z_lo = target - buffer, z_hi = target + buffer;
               double small=protected_price;
               bool counter=ScpStrongCounter(prev,cur,dir,z_lo,z_hi,m1.Atr(),buffer,small,opened);
               if(TimeCurrent()>cur.known_at+2) counter=false;
               if(counter)
                 {
                  string why = "";
                  if(exec.CloseOurPosition(why))
                    {
                     note = "phản ứng ngược tại vùng mục tiêu: " + why;
                     return SCP_MG_CLOSE;
                    }
                  note = "phản ứng ngược nhưng chưa đóng được: " + why;
                  return SCP_MG_ERROR;
                 }
              }
           }
        }
      // Chốt một phần chỉ một lần. Đã xác nhận giảm khối lượng mới bảo vệ phần còn lại.
      int stage=(int)st.Get(SK_SCALE_STATE);
      double part=st.Get(SK_SCALE_VOL), at=st.Get(SK_SCALE_AT);
      bool just_scaled=false;
      if(part>0 && stage<2 && (stage==1 || (at>0 && cur_mfe>=at)))
        {
         int result=exec.PartialOnce(note);
         if(result<0) return SCP_MG_ERROR;
         if(result==1) return SCP_MG_NONE;
         just_scaled=(result==2);
         stage=(int)st.Get(SK_SCALE_STATE);
         if(!exec.FindOurPosition(ticket,vol,entry,dir,sl,tp,opened)) return SCP_MG_NONE;
        }
      // 0,01 lot bảo vệ khi đủ 2–3 giá; lệnh chia được thì bảo vệ ngay sau khi chốt phần.
      double be_at=st.Get(SK_BE_AT,2.5);
      if(part>0 && stage<2) be_at=0;
      if(stage==2) be_at=0.0000001;
      double tick=SymbolInfoDouble(m_symbol,SYMBOL_TRADE_TICK_SIZE);
      double required=MathMax(SymbolInfoInteger(m_symbol,SYMBOL_TRADE_STOPS_LEVEL),
                              SymbolInfoInteger(m_symbol,SYMBOL_TRADE_FREEZE_LEVEL))*SymbolInfoDouble(m_symbol,SYMBOL_POINT);
      double be_sl=0;
      exit_now=dir>0 ? SymbolInfoDouble(m_symbol,SYMBOL_BID) : SymbolInfoDouble(m_symbol,SYMBOL_ASK);
      if(ScpEntryStop(dir,entry,exit_now,sl,be_at,tick,required,be_sl))
        {
         string why="";
         if(!exec.ModifyProtection(ticket,be_sl,tp,why))
           { note="chưa kéo được dừng về giá vào: "+why; return SCP_MG_ERROR; }
         st.Set(SK_POS_SL,be_sl); st.Flush();
         note=(just_scaled ? note+"; " : "")+"dừng về giá vào, giữ nguyên mục tiêu";
         return just_scaled ? SCP_MG_PARTIAL : SCP_MG_TIGHTEN;
        }
      if(just_scaled) return SCP_MG_PARTIAL;
      // 4) Siết dừng theo cấu trúc M1 mới hình thành sau khi khớp (SPEC 11.2),
      //    chỉ sau khi đã đi thuận m_trail_r lần khoảng dừng ban đầu.
      double r0 = st.Get(SK_POS_R0, 0.0);
      bool trail_ok = ScpTrailAllowed(mfe, r0, m_trail_r);
      if(trail_ok && m1 != NULL && m1.Count() > 0)
        {
         double pivot = (dir > 0) ? m1.LastPivotPrice(false) : m1.LastPivotPrice(true);
         datetime pivot_known = (dir > 0) ? m1.LastPivotKnownAt(false) : m1.LastPivotKnownAt(true);
         if(pivot > 0.0 && pivot_known > opened && m1.LastPivotBarTime(dir<0) >= opened)
           {
            double new_sl = (dir > 0) ? (pivot - buffer) : (pivot + buffer + spread);
            new_sl=dir>0 ? ScpRoundDownToTick(new_sl,tick) : ScpRoundUpToTick(new_sl,tick);
            double stops = (double)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL) * SymbolInfoDouble(m_symbol, SYMBOL_POINT);
            double freeze=SymbolInfoInteger(m_symbol,SYMBOL_TRADE_FREEZE_LEVEL)*SymbolInfoDouble(m_symbol,SYMBOL_POINT);
            double min_dist = MathMax(MathMax(stops,freeze), buffer);
            bool better = (dir > 0) ? (new_sl > sl + 1e-9) : (new_sl < sl - 1e-9 || sl == 0.0);
            bool valid = (dir > 0) ? (new_sl < bid - min_dist) : (new_sl > ask + min_dist);
            if(better && valid)
              {
               if(exec.ModifyProtection(ticket, new_sl, tp, note))
                 {
                  st.Set(SK_POS_SL, new_sl);
                  st.Flush();
                  note = "siết dừng " + DoubleToString(sl, 3) + " → " + DoubleToString(new_sl, 3) +
                         ", giữ nguyên chốt " + DoubleToString(tp, 3);
                  return SCP_MG_TIGHTEN;
                 }
               note = "siết dừng không thành công: " + note;
               return SCP_MG_ERROR;
              }
           }
        }
      return SCP_MG_NONE;
     }
  };

#endif // SCP_MANAGE_MQH
