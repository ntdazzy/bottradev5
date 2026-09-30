// ScpPlan.mqh — lập kế hoạch, kiểm chi phí, tiền chịu lỗ và khối lượng (SPEC mục 9.4, 10, 14.6, 14.9).
// Hàm thuần theo hợp đồng: tiền lời/lỗ lấy qua ScpMoneySource để test được không cần sàn thật.
#ifndef SCP_PLAN_MQH
#define SCP_PLAN_MQH

#include "ScpTypes.mqh"
#include "ScpSeries.mqh"

struct ScpSymbolSpec
  {
   string            symbol;
   double            tick_size;
   double            point;
   int               digits;
   double            volume_min;
   double            volume_max;
   double            volume_step;
   int               stops_level_points;
   double            spread_now;
   double            commission_per_lot;   // hoa hồng khứ hồi mỗi lot (0 nếu không có)
  };

// Nguồn tính tiền theo sàn. Bản thật dùng OrderCalcProfit/OrderCalcMargin.
class ScpMoneySource
  {
public:
   virtual bool      Profit(int dir, double volume, double entry, double exit, double &money) { money = 0.0; return false; }
   virtual bool      Margin(int dir, double volume, double price, double &money) { money = 0.0; return false; }
   virtual double    Equity() { return 0.0; }
   virtual double    FreeMargin() { return 0.0; }
   virtual double    SlippagePerLeg() { return 0.5; }   // đệm trượt mỗi chặng thị trường (SPEC 13)
   virtual bool      Connected() { return false; }
  };

class ScpRealMoney : public ScpMoneySource
  {
private:
   string            m_symbol;
   double            m_slip;
public:
   void              Init(const string sym, double slip_per_leg = 0.5) { m_symbol = sym; m_slip = slip_per_leg; }
   virtual double    SlippagePerLeg() { return m_slip; }
   virtual bool      Profit(int dir, double volume, double entry, double exit, double &money)
     {
      ENUM_ORDER_TYPE t = (dir > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      return OrderCalcProfit(t, m_symbol, volume, entry, exit, money);
     }
   virtual bool      Margin(int dir, double volume, double price, double &money)
     {
      ENUM_ORDER_TYPE t = (dir > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      return OrderCalcMargin(t, m_symbol, volume, price, money);
     }
   virtual double    Equity() { return AccountInfoDouble(ACCOUNT_EQUITY); }
   virtual double    FreeMargin() { return AccountInfoDouble(ACCOUNT_MARGIN_FREE); }
   virtual bool      Connected() { return (bool)TerminalInfoInteger(TERMINAL_CONNECTED); }
  };

class ScpPlanBuilder
  {
private:
   ScpMoneySource   *m_money;
   long              m_next_plan;
   double            m_risk_pct;
   double            m_min_rr;
   double            m_min_stop_atr;
   double            m_far_atr;
   double            m_partial_at, m_be_at;
   double            m_be_r;      // bảo vệ giá vào khi đi thuận max(m_be_at, m_be_r * khoảng dừng); 0 là chỉ dùng m_be_at

   bool Reward(int dir,double volume,double entry,double tp,const ScpSymbolSpec &sp,double &money,bool use_partial=true)
     {
      double part=use_partial && m_partial_at>0 ? ScpHalfVolume(volume,sp.volume_min,sp.volume_step) : 0;
      if(part<=0 || dir*(tp-entry)<=m_partial_at)
         return NetMoney(dir,volume,entry,tp,sp.commission_per_lot,money);
      double first=0,last=0;
      if(!NetMoney(dir,part,entry,entry+dir*m_partial_at,sp.commission_per_lot,first) ||
         !NetMoney(dir,volume-part,entry,tp,sp.commission_per_lot,last)) return false;
      if(first<=0) { money=first; return true; } // không gọi phần chốt bị phí ăn hết là bảo vệ lời
      money=first+last;
      return true;
     }

   // Tiền lời/lỗ ròng: đã trừ hoa hồng và đệm trượt hai chặng thị trường.
   bool              NetMoney(int dir, double volume, double entry, double exit,
                              double commission_per_lot, double &net)
     {
      double p = 0.0;
      if(!m_money.Profit(dir, volume, entry, exit, p))
         return false;
      double fees = commission_per_lot * volume;   // mở và đóng
      double slip = 0.0;
      double ref = 0.0;
      double probe = MathMax(1.0, MathAbs(entry) * 0.00001);
      if(!m_money.Profit(dir, volume, entry, entry + dir * probe, ref) || ref <= 0) return false;
      slip = MathAbs(ref / probe) * m_money.SlippagePerLeg() * 2.0;
      net = p - fees - slip;
      return true;
     }

   // Giá vào tệ nhất còn đạt tỷ lệ yêu cầu (mua: giá cao nhất; bán: giá thấp nhất).
   double            EntryLimitByRR(int dir, double sl, double tp, const ScpSymbolSpec &sp, double now_price, double atr_ref,double volume,bool use_partial)
     {
      double best = now_price;
      double worst = now_price + dir * 0.5 * atr_ref;
      for(int i = 0; i < 12; i++)
        {
         double mid = (best + worst) / 2.0;
         double loss = 0.0, win = 0.0;
         if(!NetMoney(dir, volume, mid, sl, sp.commission_per_lot, loss) ||
            !Reward(dir,volume,mid,tp,sp,win,use_partial))
            return now_price;
         loss = MathAbs(loss);
         double rr = (loss > 0.0) ? win / loss : 0.0;
         if(rr >= m_min_rr)
            best = mid;
         else
            worst = mid;
        }
      return best;
     }

   double            CostMoney(int dir, double volume, double entry, double commission_per_lot)
     {
      double fees = commission_per_lot * volume;
      double ref = 0.0;
      double probe = MathMax(1.0, MathAbs(entry) * 0.00001);
      double slip = 0.0;
      if(m_money.Profit(dir, volume, entry, entry + dir * probe, ref))
         slip = MathAbs(ref / probe) * m_money.SlippagePerLeg() * 2.0;
      return fees + slip;
     }

public:
                     ScpPlanBuilder()
     {
      m_money = NULL;
      m_next_plan = 1;
      m_risk_pct = 0.25;
      m_min_rr = 1.2;
      m_min_stop_atr = 0.5;
      m_far_atr = 0.25;
      m_partial_at=0; m_be_at=2.5; m_be_r=0;
     }

   void              Init(ScpMoneySource *money, double risk_pct, double min_rr,double partial_at=0,double be_at=2.5,double be_r=0)
     {
      m_money = money;
      m_risk_pct = risk_pct;
      m_min_rr = min_rr;
      m_partial_at=partial_at; m_be_at=be_at; m_be_r=be_r;
     }

   // Lập kế hoạch từ đề nghị. Trả về true nếu đủ điều kiện gửi (chưa gửi).
   bool              Build(const ScpProposal &p, const ScpQuote &q, const ScpSymbolSpec &sp,
                           ScpPlan &out, ENUM_SCP_SKIP &skip, string &why)
     {
      skip = SCP_SKIP_NONE;
      why = "";
      if(m_money == NULL || !m_money.Connected())
        {
         skip = SCP_SKIP_MONEY_CALC;
         why = "chưa có nguồn tính tiền/kết nối";
         return false;
        }
      if(sp.tick_size <= 0.0 || sp.volume_step <= 0.0 || sp.volume_min <= 0.0)
        {
         skip = SCP_SKIP_MONEY_CALC;
         why = "thiếu thông số sản phẩm";
         return false;
        }
      if(p.entry_tf != SCP_TF_M1 && p.entry_tf != SCP_TF_M5)
        { skip = SCP_SKIP_NO_DATA; why = "khung vào phải M1/M5"; return false; }
      if(p.reaction_known_at <= 0 || q.time < p.reaction_known_at || q.time > p.reaction_known_at + 2 ||
         (p.reaction_mono > 0 && (uint)(GetTickCount() - p.reaction_mono) > 2000))
        { skip = SCP_SKIP_STALE_SIGNAL; why = "xác nhận đã hết hạn"; return false; }
      if(p.atr_m1 <= 0 || p.atr_ref <= 0 || sp.commission_per_lot < 0)
        { skip = SCP_SKIP_NO_DATA; why = "thiếu ATR quản lý hoặc phí"; return false; }
      int dir = p.direction;
      if((dir != 1 && dir != -1) || p.reaction_bid <= 0 ||
         dir * (q.bid - p.reaction_bid) > m_far_atr * p.atr_ref ||
         dir * (q.bid - p.confirmation_edge) <= 0)
        { skip = SCP_SKIP_TOO_FAR; why = "giá đã chạy xa hoặc mất phía xác nhận"; return false; }
      double eps = MathMax(2.0 * sp.tick_size, p.atr_ref * SCP_K_BUFFER);
      double stop_buffer = MathMax(eps, sp.spread_now);
      double target_buffer = stop_buffer;
      double entry = (dir > 0) ? q.ask : q.bid;
      double sl = (dir > 0) ? (p.invalidation - stop_buffer) : (p.invalidation + stop_buffer + sp.spread_now);
      double tp = (dir > 0) ? (p.target_edge - target_buffer) : (p.target_edge + target_buffer + sp.spread_now);
      // SL làm tròn ra ngoài; TP làm tròn về phía chốt sớm hơn.
      string geometry="; entry="+DoubleToString(entry,3)+", invalid="+DoubleToString(p.invalidation,3)+
                      ", sl="+DoubleToString(sl,3)+", tp="+DoubleToString(tp,3)+
                      ", edge="+DoubleToString(p.target_edge,3)+", buffer="+DoubleToString(stop_buffer,3)+
                      ", atr="+DoubleToString(p.atr_ref,3)+", spread="+DoubleToString(sp.spread_now,3);
      if(dir > 0)
        {
         sl = ScpRoundDownToTick(sl, sp.tick_size);
         tp = ScpRoundDownToTick(tp, sp.tick_size);
        }
      else
        {
         sl = ScpRoundUpToTick(sl, sp.tick_size);
         tp = ScpRoundUpToTick(tp, sp.tick_size);
        }
      if(dir > 0)
        {
         if(!(sl < entry && tp > entry))
           {
            skip = SCP_SKIP_NO_TARGET;
            why = (!(sl<entry) ? "STOP_WRONG_SIDE" : "TARGET_TOO_CLOSE")+geometry;
            return false;
           }
        }
      else
        {
         if(!(sl > entry && tp < entry))
           {
            skip = SCP_SKIP_NO_TARGET;
            why = (!(sl>entry) ? "STOP_WRONG_SIDE" : "TARGET_TOO_CLOSE")+geometry;
            return false;
           }
        }
      double stop_dist = MathAbs(entry - sl);
      if(stop_dist < m_min_stop_atr * p.atr_ref)
        {
         skip = SCP_SKIP_STOP_TOO_CLOSE;
         why = "khoảng dừng " + DoubleToString(stop_dist, 3) + " < 0,5 ATR";
         return false;
        }
      if(sp.stops_level_points > 0)
        {
         double min_dist = sp.stops_level_points * sp.point;
         if((dir > 0 && (q.bid - sl < min_dist || tp - q.bid < min_dist)) ||
            (dir < 0 && (sl - q.ask < min_dist || q.ask - tp < min_dist)))
           {
            skip = SCP_SKIP_STOP_TOO_CLOSE;
            why = "dưới khoảng cách dừng tối thiểu của sàn";
            return false;
           }
        }
      // Tỷ lệ ròng tại khối lượng tham chiếu.
      double ref = sp.volume_min;
      double loss = 0.0, win = 0.0;
      if(!NetMoney(dir, ref, entry, sl, sp.commission_per_lot, loss) ||
         !NetMoney(dir, ref, entry, tp, sp.commission_per_lot, win))
        {
         skip = SCP_SKIP_MONEY_CALC;
         why = "không tính được tiền lời/lỗ";
         return false;
        }
      loss = MathAbs(loss);
      if(loss <= 0.0)
        {
         skip = SCP_SKIP_MONEY_CALC;
         why = "không tính được tiền lỗ tại mốc dừng";
         return false;
        }
      if(win <= 0.0)
        {
         skip = SCP_SKIP_RR_LOW;
         why = "lời ròng sau chi phí không dương"+geometry;
         return false;
        }
      double rr = win / loss;
      if(rr < m_min_rr)
        {
         skip = SCP_SKIP_RR_LOW;
         why = "tỷ lệ ròng " + DoubleToString(rr, 3) + " < " + DoubleToString(m_min_rr, 2)+geometry;
         return false;
        }
      // Khối lượng theo ngân sách rủi ro, làm tròn xuống; nếu phí không tuyến tính thì hạ tiếp.
      double budget = m_money.Equity() * m_risk_pct / 100.0;
      if(budget <= 0.0)
        {
         skip = SCP_SKIP_MONEY_CALC;
         why = "chưa có vốn tài khoản";
         return false;
        }
      double raw = budget / (loss / ref);
      double steps = MathFloor(raw / sp.volume_step + 1e-9);
      double vol = 0.0;
      double risk_final = 0.0, win_final = 0.0;
      bool vol_ok = false;
      for(int guard = 0; guard < 10000 && steps >= 1; guard++)
        {
         vol = steps * sp.volume_step;
         if(vol > sp.volume_max)
            vol = sp.volume_max;
         if(vol < sp.volume_min)
            break;
         if(!NetMoney(dir, vol, entry, sl, sp.commission_per_lot, risk_final) ||
            !NetMoney(dir, vol, entry, tp, sp.commission_per_lot, win_final))
           {
            skip = SCP_SKIP_MONEY_CALC;
            why = "không tính được tiền ở khối lượng chốt";
            return false;
           }
         risk_final = MathAbs(risk_final);
         if(risk_final <= budget + 1e-9)
           {
            vol_ok = true;
            break;
           }
         steps -= 1.0;
        }
      if(!vol_ok)
        {
         skip = SCP_SKIP_VOLUME_MIN;
         why = "khối lượng nhỏ nhất vẫn vượt ngân sách hoặc dưới mức nhỏ nhất";
         return false;
        }
      double full_reward=win_final;
      bool use_partial=true;
      if(!Reward(dir,vol,entry,tp,sp,win_final))
        { skip=SCP_SKIP_MONEY_CALC; why="không tính được lời của hai phần"; return false; }
      // Chia lệnh là tùy chọn. Không đổi SL/TP/lot để cứu kế hoạch chia không đạt.
      if(win_final/risk_final<m_min_rr && full_reward/risk_final>=m_min_rr)
        { use_partial=false; win_final=full_reward; }
      rr=win_final/risk_final;
      if(rr<m_min_rr)
        { skip=SCP_SKIP_RR_LOW; why="tỷ lệ sau chốt một phần "+DoubleToString(rr,3)+" dưới ngưỡng"; return false; }
      double margin = 0.0;
      if(!m_money.Margin(dir, vol, entry, margin) || margin <= 0.0)
        {
         skip = SCP_SKIP_MARGIN;
         why = "không tính được ký quỹ";
         return false;
        }
      if(m_money.FreeMargin() < margin)
        {
         skip = SCP_SKIP_MARGIN;
         why = "không đủ ký quỹ trống";
         return false;
        }
      // Giới hạn giá vào: tỷ lệ còn đạt và không đuổi quá xa giá xác nhận.
      double by_rr = EntryLimitByRR(dir, sl, tp, sp, entry, p.atr_ref,vol,use_partial);
      double far = p.reaction_bid + dir * m_far_atr * p.atr_ref + (dir > 0 ? sp.spread_now : 0);
      double limit_price = (dir > 0) ? MathMin(by_rr, far) : MathMax(by_rr, far);
      limit_price = dir > 0 ? ScpRoundDownToTick(limit_price, sp.tick_size) : ScpRoundUpToTick(limit_price, sp.tick_size);
      out.plan_id = m_next_plan++;
      out.spec_version = SCP_SPEC_VERSION;
      out.parameter_hash = SCP_SPEC_VERSION + "|rr" + DoubleToString(m_min_rr, 2) + "|risk" + DoubleToString(m_risk_pct, 2);
      out.parameter_hash+="|part"+DoubleToString(m_partial_at,3)+"|be"+DoubleToString(m_be_at,3);
      out.symbol = sp.symbol;
      out.episode_id = p.episode_id;
      out.scenario = p.scenario;
      out.zone_id = p.zone_id;
      out.entry_tf = p.entry_tf;
      out.management_tf = p.management_tf;
      out.direction = dir;
      out.context = p.context;
      out.thesis = p.thesis;
      out.reaction_known_at = p.reaction_known_at;
      out.sent_at = 0;
      out.provisional = p.provisional;
      out.entry_price_limit = limit_price;
      out.invalidation = p.invalidation;
      out.sl = sl;
      out.tp = tp;
      out.target_zone_id = p.target_zone_id;
      out.target_edge_bid = p.target_edge;
      out.expected_cost = CostMoney(dir, vol, entry, sp.commission_per_lot);
      out.expected_risk = risk_final;
      out.expected_reward = win_final;
      out.net_reward_risk = (risk_final > 0.0) ? win_final / risk_final : 0.0;
      out.volume = vol;
      out.atr_ref = p.atr_ref;
      out.send_deadline = p.reaction_known_at + 2;
      out.reaction_mono = p.reaction_mono;
      out.reaction_bid = p.reaction_bid;
      out.confirmation_edge = p.confirmation_edge;
      out.atr_m1 = p.atr_m1;
      out.risk_budget = budget;
      // Các trường được giữ để đọc sổ cũ; giá trị 0 nghĩa là không có hạn đóng theo đồng hồ.
      out.hold_seconds = 0;
      out.progress_seconds = 0;
      out.hold_deadline = 0;
      out.no_progress_deadline = 0;
      out.market_only = true;
      out.partial_volume=(use_partial && m_partial_at>0 && dir*(tp-entry)>m_partial_at) ? ScpHalfVolume(vol,sp.volume_min,sp.volume_step) : 0;
      out.partial_trigger=m_partial_at;
      out.breakeven_trigger=MathMax(m_be_at,m_be_r*stop_dist);
      why = "kế hoạch " + IntegerToString((int)out.plan_id) + ": " + ScpScenarioName(p.scenario) +
            " " + (dir > 0 ? "MUA" : "BÁN") + " " + DoubleToString(vol, 3) + " lot, vào "
            + DoubleToString(entry, (int)sp.digits) + ", dừng " + DoubleToString(sl, (int)sp.digits) +
            ", chốt " + DoubleToString(tp, (int)sp.digits) + ", rủi ro " + DoubleToString(risk_final, 2) +
            ", tỷ lệ " + DoubleToString(rr, 2)+(use_partial ? "" : "; giữ toàn bộ vì chia lệnh làm giảm lợi thế");
      return true;
     }
  };

#endif // SCP_PLAN_MQH
