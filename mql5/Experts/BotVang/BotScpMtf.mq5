// BotScpMtf.mq5 — EA bot SCP-MTF-1.0 theo docs/SPEC.md.
// Mặc định QUAN SÁT: không gửi lệnh. Muốn gửi phải bật rõ từng nhánh bằng input.
// Trạng thái và việc còn lại: docs/HANDOFF.md.
#property strict

#include <BotVang\ScpTypes.mqh>
#include <BotVang\ScpSeries.mqh>
#include <BotVang\ScpZones.mqh>
#include <BotVang\ScpEpisodes.mqh>
#include <BotVang\ScpReaction.mqh>
#include <BotVang\ScpScenario.mqh>
#include <BotVang\ScpPlan.mqh>
#include <BotVang\ScpFeed.mqh>
#include <BotVang\ScpJournal.mqh>
#include <BotVang\ScpState.mqh>
#include <BotVang\ScpSafety.mqh>
#include <BotVang\ScpExec.mqh>
#include <BotVang\ScpManage.mqh>

input bool   InpEnabled      = true;    // quan sát và ghi nhật ký
input bool   InpSendEnabled  = false;   // CHỈ bật trong máy thử khi đã có phép; mặc định tắt
input bool   InpSendS01      = false;   // cho phép gửi nhánh S01
input bool   InpSendS02      = false;
input bool   InpSendS03      = false;
input bool   InpSendS04      = false;
input bool   InpSendS05      = false;
input bool   InpSendS06      = false;
input bool   InpSendS07      = false;
input bool   InpSendS08      = false;
input long   InpMagic        = 770001;
input string InpRunName      = "scp_run";
input double InpRiskPct      = 0.25;    // % vốn mỗi lệnh
input double InpMinRR        = 1.5;     // tỷ lệ ròng cả lệnh, gồm phần chốt đầu
input double InpPartialAtPrice = 3.0;   // đi thuận 3 giá: chốt phần; 0 tắt để đối chứng
input double InpBreakevenAtPrice = 2.5; // vị thế không chia được: dừng về giá vào
input double InpDayLossPct   = 2.0;     // giới hạn lỗ ngày
input double InpWeekLossPct  = 5.0;     // giới hạn lỗ tuần
input double InpTotalLossPct = 8.0;     // giới hạn lỗ tổng
input int    InpUtcOffset    = 7;       // múi giờ rủi ro (SPEC 14.10)
input int    InpBrokerUtcOffset = 0;   // phải xác thực theo máy chủ; nghiên cứu Exness dùng UTC
input int    InpMaxQuoteMs   = 2000;    // độ mới báo giá tối đa
input double InpCommissionRoundTrip = -1.0; // phí khứ hồi mỗi lot, -1 chưa biết
input bool   InpAllowDemo = false; // quyền demo riêng; tiền thật bị chặn
input double InpBreakevenR   = 1.0;     // bảo vệ giá vào khi đi thuận max(InpBreakevenAtPrice, R lần khoảng dừng); 0 = chỉ theo giá
input double InpTrailAfterR  = 1.0;     // chỉ siết theo cấu trúc sau khi đi thuận R lần khoảng dừng; 0 = siết ngay (cách cũ)
input bool   InpM1TargetNeedsReaction = true; // vùng M1 chỉ làm cản mục tiêu khi đã có phản ứng; false = cách cũ
input bool   InpUseM1MinorZones = false; // true = mở theo dõi cả đỉnh/đáy, FVG, MSNR M1 (cách cũ); false = chỉ OB M1 và vùng M5 trở lên
input double InpSlipPerLeg   = 0.5;     // đệm trượt giả định mỗi chặng (giá); chưa phải số đo thực
input bool   InpLogZones     = false;
input bool   InpFullDump     = false;

ScpFrames           g_fr;
ScpFeed             g_feed;
ScpZoneMap          g_zones;
ScpEpisodeMap       g_eps;
ScpScenarioEngine   g_scen;
ScpRealMoney        g_money;
ScpPlanBuilder      g_plan;
ScpJournal          g_journal;
ScpState            g_state;
ScpRiskLedger       g_risk;
ScpSpreadGuard      g_spread;
ScpNewsGuard        g_news;
ScpExec             g_exec;
ScpManage           g_manage;

long                g_seen_pivot[SCP_TF_COUNT];
int                 g_touches, g_proposals, g_plans, g_skips, g_sent, g_closed;
ENUM_SCP_SKIP       g_last_skip;
string              g_last_skip_why;
bool                g_last_news_missing;
ulong               g_calc_us[4096], g_send_us[256];
int                 g_calc_n=0, g_send_n=0;
ulong               g_send_this_tick=0;
datetime            g_small_known[2];
double              g_small_high[2],g_small_low[2];

void PrintLatency(ulong &samples[], int count, string label)
  {
   int n=MathMin(count,ArraySize(samples));
   if(n<=0) { Print("[SCP][PERF] ",label,": chưa có mẫu"); return; }
   ulong ordered[]; ArrayResize(ordered,n); ArrayCopy(ordered,samples,0,0,n); ArraySort(ordered);
   Print("[SCP][PERF] ",label," mẫu cuối=",n," tổng=",count," us p50=",ordered[n/2],
         " p95=",ordered[(int)MathCeil(n*0.95)-1]," p99=",ordered[(int)MathCeil(n*0.99)-1]);
  }

// ---------------------------------------------------------------- vùng mới từ nến đóng

void AddNewZonesFromPivots()
  {
   for(int tf = 0; tf < SCP_TF_COUNT; tf++)
     {
      ScpSeries *s = g_fr.Get(tf);
      if(s == NULL)
         continue;
      for(int i = 0; i < s.PivotCount(); i++)
        {
         ScpPivot p = s.Pivot(i);
         if(p.id <= g_seen_pivot[tf])
            continue;
         g_seen_pivot[tf] = p.id;
         ScpBar src = s.Bar(s.Count() - 1);
         bool found = false;
         int from = MathMax(0, s.Count() - SCP_ZONE_MAX_AGE - 1);
         for(int b = s.Count() - 1; b >= from; b--)
           {
            ScpBar bb = s.Bar(b);
            if(bb.open_time == p.bar_time)
              {
               src = bb;
               if(s.Count() - 1 - b > SCP_ZONE_MAX_AGE)
                 {
                  found = false;
                  break;
                 }
               found = true;
               break;
              }
           }
         if(!found)
            continue;
         double atr = s.Atr();
         long zid = g_zones.AddFromPivot((ENUM_SCP_TF)tf, src, p.is_high, p.known_at, atr,
                                         SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE));
         if(zid > 0 && InpLogZones)
           {
            ScpZone z;
            if(g_zones.Find(zid, z))
               g_journal.ZoneLine(z);
           }
        }
     }
  }

void AddMsnrOnly(int tf_index)
  {
   ScpSeries *s = g_fr.Get(tf_index);
   if(s == NULL || s.Count() < 3)
      return;
   int n = s.Count();
   ScpBar b = s.Bar(n - 2);
   ScpBar c = s.Bar(n - 1);
   bool b_up = (b.c > b.o);
   bool c_up = (c.c > c.o);
   if(b.c == b.o || c.c == c.o) return;
   if(b_up && !c_up)
      g_zones.AddMsnr((ENUM_SCP_TF)tf_index, b.c, SCP_ROLE_RESISTANCE, b.open_time, c.known_at);
   else
      if(!b_up && c_up)
         g_zones.AddMsnr((ENUM_SCP_TF)tf_index, b.c, SCP_ROLE_SUPPORT, b.open_time, c.known_at);
  }

void AddFvgAndMsnr(int tf_index)
  {
   ScpSeries *s = g_fr.Get(tf_index);
   if(s == NULL || s.Count() < 4)
      return;
   int n = s.Count();
   ScpBar a = s.Bar(n - 3);
   ScpBar b = s.Bar(n - 2);
   ScpBar c = s.Bar(n - 1);
   double tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double atr = s.Atr();
   if(c.l > a.h && b.c > b.o)
      g_zones.AddFvg((ENUM_SCP_TF)tf_index, +1, a.h, c.l, a.open_time, c.known_at, atr, tick, false);
   if(c.h < a.l && b.c < b.o)
      g_zones.AddFvg((ENUM_SCP_TF)tf_index, -1, c.h, a.l, a.open_time, c.known_at, atr, tick, false);
  }

void OnFramesUpdated(const bool &changed[])
  {
   AddNewZonesFromPivots();
   g_zones.ExpireByAge(g_fr);
   g_eps.PruneWatches(g_zones);
   for(int tf = 0; tf < SCP_TF_COUNT; tf++)
     {
      if(!changed[tf]) continue;
      AddFvgAndMsnr(tf);
      AddMsnrOnly(tf);
      ScpSeries *s=g_fr.Get(tf);
      if(s==NULL || s.Count()<3) continue;
      ScpBar last=s.LastBar(), before=s.Bar(s.Count()-2);
      double hi=s.LastPivotPrice(true),lo=s.LastPivotPrice(false);
      double eps=SCP_K_BUFFER*s.AtrAt(s.Count()-2);
      int dir=0;
      if(hi>0 && s.LastPivotKnownAt(true)<=last.open_time && before.c<=hi+eps && last.c>hi+eps) dir=1;
      if(lo>0 && s.LastPivotKnownAt(false)<=last.open_time && before.c>=lo-eps && last.c<lo-eps) dir=-1;
      if(dir!=0)
         for(int k=s.Count()-2;k>=MathMax(0,s.Count()-1-SCP_OB_LOOKBACK);k--)
           {
            ScpBar prev=s.Bar(k);
            if((dir>0 && prev.c<prev.o)||(dir<0 && prev.c>prev.o))
              { g_zones.AddOb((ENUM_SCP_TF)tf,prev,dir,last.known_at,SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)); break; }
           }
     }
  }

void OnBarClosed(int tf_index)
  {
   ScpSeries *s = g_fr.Get(tf_index);
   if(s == NULL || s.Count() < 1)
      return;
   ScpBar bar = s.Bar(s.Count() - 1);
   double eps = SCP_K_BUFFER * s.Atr();
   g_zones.OnSourceBar((ENUM_SCP_TF)tf_index,bar,s.Bar(s.Count()-2),s.AtrAt(s.Count()-2),eps);
   if(tf_index<2) g_eps.OnBarClosed(tf_index, bar, g_zones, eps, bar.known_at);
  }

void WatchZones(const ScpQuote &q)
  {
   double tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   for(int tf = 0; tf < 2; tf++)
     {
      ScpSeries *s = g_fr.Get(tf);
      if(s == NULL || !s.Info().data_ok)
         continue;
      double eps = MathMax(2.0 * tick, SCP_K_BUFFER * s.Atr());
      // Các vùng cùng khung dùng cùng pivot đã biết; không tìm lại cho từng vùng.
      if(g_small_known[tf]!=s.Info().known_at)
        {
         g_small_high[tf]=s.SmallPivot(true,s.Count()-1,20,q.time);
         g_small_low[tf]=s.SmallPivot(false,s.Count()-1,20,q.time);
         g_small_known[tf]=s.Info().known_at;
        }
      for(int i = 0; i < g_zones.Count(); i++)
        {
         ScpZone z = g_zones.At(i);
         if(!z.alive || z.known_at > q.time)
            continue;
         // Vùng M1 li ti chỉ để xác nhận/đặt mốc, không mở lần theo dõi vào lệnh (trừ OB M1).
         if(!InpUseM1MinorZones && z.source_tf == SCP_TF_M1 && z.type != SCP_ZONE_OB)
            continue;
         double dist = 0.0;
         if(q.bid < z.bottom)
            dist = z.bottom - q.bid;
         else
            if(q.bid > z.top)
               dist = q.bid - z.top;
         if(dist > 3.0 * MathMax(s.Atr(), eps) + eps)
            continue;
         long eid = g_eps.Watch(z, q.bid, eps, q.time, (ENUM_SCP_TF)tf, s.Atr(), (datetime)g_state.Get(SK_LAST_CLOSE),
                                g_small_high[tf],g_small_low[tf]);
         if(eid > 0)
           {
            g_touches++;
            g_zones.RegisterTouch(z.id, q.time);
            if(InpFullDump)
               g_journal.Decision(q.time, "-", 0, IntegerToString((int)z.id), ScpTfName((ENUM_SCP_TF)tf),
                                  "CHAM_VUNG", "mở episode " + IntegerToString((int)eid));
           }
        }
     }
  }

// ---------------------------------------------------------------- cổng gửi

bool BranchAllowed(ENUM_SCP_SCENARIO sc)
  {
   switch(sc)
     {
      case SCP_SC_S01:
         return InpSendS01;
      case SCP_SC_S02:
         return InpSendS02;
      case SCP_SC_S03:
         return InpSendS03;
      case SCP_SC_S04:
         return InpSendS04;
      case SCP_SC_S05:
         return InpSendS05;
      case SCP_SC_S06:
         return InpSendS06;
      case SCP_SC_S07:
         return InpSendS07;
      case SCP_SC_S08:
         return InpSendS08;
     }
   return false;
  }

bool GateSkip(ENUM_SCP_SKIP &skip, string &why)
  {
   skip = SCP_SKIP_NONE;
   why = "";
   if(!g_state.Healthy() || !g_journal.Ready())
     { skip=SCP_SKIP_NO_DATA; why="trạng thái không lưu được"; return true; }
   if(!MQLInfoInteger(MQL_TESTER) &&
      (!InpAllowDemo || AccountInfoInteger(ACCOUNT_TRADE_MODE)!=ACCOUNT_TRADE_MODE_DEMO))
     { skip=SCP_SKIP_NO_DATA; why="chưa cho phép demo; tiền thật bị chặn"; return true; }
   if(!g_spread.Ready((long)GetTickCount()))
     { skip=SCP_SKIP_SPREAD; why="chưa đủ 30 báo giá"; return true; }
   if(!InpSendEnabled)
     {
      skip = SCP_SKIP_DUPLICATE;
      why = "chưa bật gửi lệnh";
      return true;
     }
   if(g_exec.Busy() || g_exec.HasOurPosition() || g_exec.HasOurPendingOrder())
     {
      skip = SCP_SKIP_HAS_POSITION;
      why = "đã có vị thế hoặc kế hoạch đang dở";
      return true;
     }
   if(g_exec.HasForeignExposure())
     {
      skip = SCP_SKIP_HAS_POSITION;
      why = "có vị thế/lệnh không thuộc bot trên cùng ký hiệu";
      return true;
     }
   if(g_risk.LockedOut())
     {
      skip = SCP_SKIP_LOSS_LIMIT;
      why = g_risk.LockText();
      return true;
     }
   if(g_spread.Spike(SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID),
                     (long)GetTickCount(), 2.0, 30))
     {
      skip = SCP_SKIP_SPREAD;
      why = "spread tăng bất thường so với trung vị 60 giây";
      return true;
     }
   if(g_news.InWindow(TimeCurrent(), 5, 5))
     {
      skip = SCP_SKIP_NEWS;
      why = "trong cửa sổ tin mạnh";
      return true;
     }
   if(!g_news.Available())
     {
      g_last_news_missing = true;
      // Thiếu lịch tin: không chặn ở chế độ nghiên cứu nhưng phải ghi rõ (SPEC 14.10).
      if(!MQLInfoInteger(MQL_TESTER))
        {
         skip = SCP_SKIP_NEWS;
         why = "thiếu lịch tin, không cho gửi ngoài máy thử";
         return true;
        }
     }
   if(!(bool)TerminalInfoInteger(TERMINAL_CONNECTED) || !(bool)AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
     {
      skip = SCP_SKIP_NO_DATA;
      why = "chưa kết nối hoặc tài khoản không cho giao dịch";
      return true;
     }
   return false;
  }

bool GateSendable(const ScpPlan &plan, const ScpQuote &q, ENUM_SCP_SKIP &skip, string &why)
  {
   skip = SCP_SKIP_NONE;
   why = "";
   uint age = (uint)GetTickCount() - q.received_msc;
   if(q.received_msc == 0 || age > (uint)InpMaxQuoteMs)
     {
      skip = SCP_SKIP_NO_DATA;
      why = "báo giá quá cũ";
      return false;
     }
   // Hết hạn từ lúc xác nhận tới lúc gửi (SPEC 13: 2 giây, dùng đồng hồ đơn điệu).
   if((plan.send_deadline > 0 && q.time > plan.send_deadline) ||
      (plan.reaction_mono>0 && (uint)(GetTickCount()-plan.reaction_mono)>2000))
     {
      skip = SCP_SKIP_STALE_SIGNAL;
      why = "tín hiệu quá hạn 2 giây";
      return false;
     }
   // Giá đã chạy xa hoặc đã quay lại sai phía.
   if(plan.direction > 0)
     {
      if(q.ask > plan.entry_price_limit)
        {
         skip = SCP_SKIP_TOO_FAR;
         why = "giá mua đã chạy quá giới hạn " + DoubleToString(plan.entry_price_limit, 8);
         return false;
        }
      if(q.bid <= plan.invalidation || q.bid <= plan.confirmation_edge)
        {
         skip = SCP_SKIP_STALE_SIGNAL;
         why = "giá đã quay lại mốc vô hiệu";
         return false;
        }
     }
   else
     {
      if(q.bid < plan.entry_price_limit)
        {
         skip = SCP_SKIP_TOO_FAR;
         why = "giá bán đã chạy quá giới hạn " + DoubleToString(plan.entry_price_limit, 8);
         return false;
        }
      if(q.bid >= plan.invalidation || q.bid >= plan.confirmation_edge)
        {
         skip = SCP_SKIP_STALE_SIGNAL;
         why = "giá đã quay lại mốc vô hiệu";
         return false;
        }
     }
   // Chặn mở sát giờ nghỉ; đây là an toàn phiên, không phải tuổi lệnh.
   int secs = ScpSecondsToSessionEnd(_Symbol, TimeCurrent());
   if(secs <= 60)
     {
      skip = SCP_SKIP_SESSION_END;
      why = "quá gần giờ nghỉ sàn";
      return false;
     }
   return true;
  }

// ---------------------------------------------------------------- vòng xử lý

bool TryProposal(const ScpProposal &p, const ScpQuote &q)
  {
   g_proposals++;
   ScpSymbolSpec sp;
   sp.symbol = _Symbol;
   sp.tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   sp.point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   sp.digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   sp.volume_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   sp.volume_max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   sp.volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   sp.stops_level_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   sp.spread_now = q.ask - q.bid;
   sp.commission_per_lot = InpCommissionRoundTrip;
   if(MQLInfoInteger(MQL_TESTER) && sp.commission_per_lot < 0) sp.commission_per_lot=0; // giả định nghiên cứu
   ScpPlan plan;
   ENUM_SCP_SKIP skip;
   string why = "";
   bool ok = g_plan.Build(p, q, sp, plan, skip, why);
   // Dùng dấu xác nhận, không tiêu thụ toàn bộ sự kiện phá. Kế hoạch bị loại không khóa cả lần chạm.
   g_scen.Consume(p,g_eps,g_zones,ok);
   if(!ok)
     {
      ScpZone target;
      if(g_zones.Find(p.target_zone_id,target))
         why+="; target_id="+(string)target.id+", tf="+ScpTfName(target.source_tf)+", type="+(string)target.type+
              ", known="+TimeToString(target.known_at,TIME_DATE|TIME_SECONDS);
     }
   g_journal.Decision(q.time, ScpScenarioName(p.scenario), p.direction, IntegerToString((int)p.zone_id),
                      ScpTfName(p.entry_tf), ok ? "KE_HOACH" : ScpSkipName(skip), ok ? p.why : why);
   if(!ok)
     {
      g_skips++;
      g_last_skip = skip;
      g_last_skip_why = why;
      return false;
     }
   g_plans++;
   if(!BranchAllowed(p.scenario)) { g_journal.PlanLine(plan,q); return false; }
   if(GateSkip(skip, why))
     {
      g_skips++;
      g_last_skip = skip;
      g_last_skip_why = why;
      g_journal.ExecLine(q.time, ScpSkipName(skip), plan.plan_id, why);
      return true;
     }
   ScpQuote fresh;
   g_feed.UpdateQuote(fresh);
   sp.spread_now = fresh.ask-fresh.bid;
   if(!g_plan.Build(p,fresh,sp,plan,skip,why))
     {
      g_skips++; g_last_skip=skip; g_last_skip_why=why;
      g_journal.Decision(fresh.time,ScpScenarioName(p.scenario),p.direction,(string)p.zone_id,
                         ScpTfName(p.entry_tf),ScpSkipName(skip),why);
      return false;
     }
   if(!GateSendable(plan, fresh, skip, why))
     {
      g_skips++;
      g_last_skip = skip;
      g_last_skip_why = why;
      g_journal.Decision(fresh.time, ScpScenarioName(p.scenario), p.direction,
                         IntegerToString((int)p.zone_id), ScpTfName(p.entry_tf), ScpSkipName(skip), why);
      return false;
     }
   string send_why = "";
   ulong send_start=GetMicrosecondCount();
   bool sent=g_exec.Send(plan, send_why);
   g_journal.PlanLine(plan,fresh);
   g_send_this_tick=GetMicrosecondCount()-send_start;
   g_send_us[g_send_n++%256]=g_send_this_tick;
   if(sent)
     {
      g_sent++;
      g_journal.ExecLine(fresh.time, "DA_GUI", plan.plan_id, send_why);
     }
   else
     {
      g_journal.ExecLine(fresh.time, "GUI_LOI", plan.plan_id, send_why);
      g_last_skip = SCP_SKIP_MONEY_CALC;
      g_last_skip_why = send_why;
      g_skips++;
     }
   return true;
  }

void TryTrade(const ScpQuote &q)
  {
   ScpProposal p;
   string conflict="";
   bool got=g_scen.Run(g_fr,g_zones,g_eps,q,p,conflict);
   if(conflict!="")
     { g_journal.Decision(q.time,"WAIT",0,"-","-","CONFLICT",conflict); return; }
   while(got)
     {
      if(TryProposal(p,q)) return;
      got=g_scen.Next(p);
     }
  }

int OnInit()
  {
   if(InpRiskPct<=0 || InpMinRR<=0 || InpPartialAtPrice<0 || InpBreakevenAtPrice<=0 ||
      InpBreakevenR<0 || InpTrailAfterR<0 || InpSlipPerLeg<0 ||
      InpDayLossPct<=0 || InpWeekLossPct<=0 || InpTotalLossPct<=0 ||
      InpTotalLossPct>100 || InpRiskPct>InpDayLossPct || InpMaxQuoteMs<=0 || InpMaxQuoteMs>2000 ||
      MathAbs(InpUtcOffset)>14 || MathAbs(InpBrokerUtcOffset)>14)
     { Print("[SCP][INIT] tham số rủi ro/thời gian không hợp lệ"); return INIT_PARAMETERS_INCORRECT; }
   g_fr.Init();
   ArrayInitialize(g_small_known,0); ArrayInitialize(g_small_high,0); ArrayInitialize(g_small_low,0);
   g_feed.Init(_Symbol, GetPointer(g_fr));
   g_zones.Init();
   g_eps.Init();
   g_scen.Init();
   g_money.Init(_Symbol, InpSlipPerLeg);
   if(!g_state.Init(_Symbol, InpMagic))
      Print("[SCP] cảnh báo: tên khóa trạng thái quá dài, có thể không lưu được");
   g_plan.Init(GetPointer(g_money), InpRiskPct, InpMinRR,InpPartialAtPrice,InpBreakevenAtPrice,InpBreakevenR);
   g_zones.SetM1TargetNeedsReaction(InpM1TargetNeedsReaction);
   if(InpSendEnabled && InpPartialAtPrice>0 && AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
     { Print("[SCP][INIT] chốt phần cần tài khoản hedging; không tự gửi đối ứng trên netting"); return INIT_PARAMETERS_INCORRECT; }
   g_risk.Init(GetPointer(g_state), InpMagic, _Symbol, InpUtcOffset-InpBrokerUtcOffset,
               InpRiskPct, InpDayLossPct, InpWeekLossPct, InpTotalLossPct);
   g_exec.Init(GetPointer(g_state), InpMagic, _Symbol);
   g_manage.Init(InpMagic, _Symbol, InpTrailAfterR);
   g_spread.Reset();
   g_news.Load();
   for(int i = 0; i < SCP_TF_COUNT; i++)
      g_seen_pivot[i] = 0;
   g_touches = g_proposals = g_plans = g_skips = g_sent = g_closed = 0;
   g_last_skip = SCP_SKIP_NONE;
   g_last_skip_why = "";
   g_last_news_missing = false;
   string folder = "BotScp\\" + InpRunName;
   if(!g_journal.Init(folder, _Symbol, InpRunName))
     { Print("[SCP] không mở được nhật ký ở ", folder); return INIT_FAILED; }
   EventSetTimer(10);
   int pushed = g_feed.Warmup(600);
   g_risk.Update(TimeCurrent());
   g_scen.OnClosed(TimeCurrent()); // không dùng xác nhận trước lúc khởi động
   if(InpSendEnabled && InpCommissionRoundTrip<0 && !MQLInfoInteger(MQL_TESTER)) return INIT_PARAMETERS_INCORRECT;
   Print("[SCP] ", SCP_SPEC_VERSION, " | gửi lệnh: ", (InpSendEnabled ? "BẬT" : "TẮT"),
         " | quan sát: ", (InpEnabled ? "BẬT" : "TẮT"), " | nến nạp trước: ", pushed,
         " | lịch tin: ", (g_news.Available() ? "có" : "THIẾU"), " | nhật ký: ", folder);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   PrintLatency(g_calc_us,g_calc_n,"phân tích và quản lý");
   PrintLatency(g_send_us,g_send_n,"gọi gửi và lưu ý định");
   string s = SCP_SPEC_VERSION+": chạm vùng=" + IntegerToString(g_touches) +
              ", đề nghị=" + IntegerToString(g_proposals) +
              ", kế hoạch=" + IntegerToString(g_plans) +
              ", bỏ=" + IntegerToString(g_skips) +
              ", đã gửi=" + IntegerToString(g_sent) +
              ", đã đóng=" + IntegerToString(g_closed) +
              ", vùng=" + IntegerToString(g_zones.Count()) + " (bỏ vì đầy " + IntegerToString(g_zones.Dropped()) + ")" +
              ", episode=" + IntegerToString(g_eps.Count()) + " (theo dõi bỏ vì đầy " + IntegerToString(g_eps.WatchDropped()) + ")" +
              ", giới hạn lỗ=" + (g_risk.LockedOut() ? g_risk.LockText() : "chưa chạm") +
              ", lý do bỏ cuối=" + ScpSkipName(g_last_skip) + " (" + g_last_skip_why + ")" +
              ", gửi lệnh=" + (InpSendEnabled ? "BẬT" : "TẮT") +
              ", lịch tin=" + (g_news.Available() ? "có" : "THIẾU");
   g_journal.Decision(TimeCurrent(), "-", 0, "-", "-", "KET_THUC", s);
   g_journal.Finish(s);
   g_state.Flush();
   g_exec.ReleaseLease();
   Print("[SCP] ", s);
  }

void ProcessTick()
  {
   // Tắt tìm lệnh không được tắt bảo vệ vị thế đang có.
   ScpQuote q;
   bool quote_changed = g_feed.UpdateQuote(q);
   bool new_bar[];
   bool any_bar = g_feed.UpdateFrames(new_bar);
   if(g_feed.Gap())
     { g_eps.Init(); g_scen.Init(); g_scen.OnClosed(TimeCurrent()); }
   if(any_bar)
     {
      OnFramesUpdated(new_bar);
      for(int tf = 0; tf < SCP_TF_COUNT; tf++)
         if(new_bar[tf])
            OnBarClosed(tf);

     }
   g_risk.Update(TimeCurrent());
   g_scen.OnClosed((datetime)g_state.Get(SK_LAST_CLOSE));
   // Đối soát và quản lý vị thế trước khi tìm lệnh mới (SPEC 11.1).
   if(g_exec.Busy() || g_exec.HasOurPosition())
     {
      long managed_plan=g_exec.PlanId();
      string note = "";
      g_exec.Reconcile(note);
      if(note != "" && InpFullDump)
         g_journal.ExecLine(TimeCurrent(), "DOI_SOAT", g_exec.PlanId(), note);
      int act=SCP_MG_NONE;
      int remaining=ScpSecondsToSessionEnd(_Symbol,TimeCurrent());
      if(g_risk.LockedOut() || (remaining>0 && remaining<=60))
        {
         if(g_exec.CloseOurPosition(note)) act=SCP_MG_CLOSE;
        }
      else if(g_exec.HasPlan()) act = g_manage.Step(g_fr.Get(SCP_TF_M1), g_exec, g_state, note,GetPointer(g_zones));
      if(act == SCP_MG_CLOSE)
        {
         g_journal.ExecLine(TimeCurrent(), "DONG", managed_plan, note);
        }
      else
         if(act == SCP_MG_TIGHTEN || act == SCP_MG_ERROR || act==SCP_MG_PARTIAL)
            g_journal.ExecLine(TimeCurrent(), (act==SCP_MG_PARTIAL ? "CHOT_PHAN" : (act == SCP_MG_TIGHTEN ? "SIET_DUNG" : "LOI_QUAN_LY")),
                               g_exec.PlanId(), note);
     }
   if(!quote_changed || !InpEnabled) return;
   for(int i=0;i<g_eps.Count();i++) g_eps.OnTick(i,q.bid);
   g_eps.Cleanup(q.time,3600);
   g_spread.Add(q.ask - q.bid, (long)GetTickCount());
   if(!g_zones.Count())
      return;
   WatchZones(q);
   TryTrade(q);
  }

void OnTick()
  {
   ulong started=GetMicrosecondCount();
   g_send_this_tick=0;
   ProcessTick();
   g_calc_us[g_calc_n++%4096]=GetMicrosecondCount()-started-g_send_this_tick;
  }

void OnTimer()
  {
   g_journal.Flush();
   // Giữ bằng chứng khi bị ngắt máy thử; không coi tóm tắt tạm là hoàn tất.
   if(MQLInfoInteger(MQL_TESTER) && g_calc_n>0 && TimeCurrent()%3600<10)
      PrintLatency(g_calc_us,g_calc_n,"mẫu tạm phân tích");
  }

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  {
   g_exec.OnTransaction(trans,request,result);
   // Nạp/rút tiền: dời mốc vốn, không xóa bộ đếm lỗ (SPEC 12, 14.10).
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
     {
      ulong d = trans.deal;
      if(d != 0 && HistoryDealSelect(d))
        {
         if(HistoryDealGetInteger(d,DEAL_MAGIC)==InpMagic && HistoryDealGetString(d,DEAL_SYMBOL)==_Symbol)
           {
            long entry=HistoryDealGetInteger(d,DEAL_ENTRY);
            long pid=HistoryDealGetInteger(d,DEAL_POSITION_ID);
            double price=HistoryDealGetDouble(d,DEAL_PRICE), volume=HistoryDealGetDouble(d,DEAL_VOLUME);
            double net=HistoryDealGetDouble(d,DEAL_PROFIT)+HistoryDealGetDouble(d,DEAL_COMMISSION)+
                       HistoryDealGetDouble(d,DEAL_SWAP)+HistoryDealGetDouble(d,DEAL_FEE);
            datetime when=(datetime)HistoryDealGetInteger(d,DEAL_TIME);
            long plan_id=0;
            if(pid>0 && HistorySelectByPosition((ulong)pid))
               for(int i=0;i<HistoryDealsTotal();i++)
                 {
                  ulong deal=HistoryDealGetTicket(i);
                  if(HistoryDealGetInteger(deal,DEAL_ENTRY)!=DEAL_ENTRY_IN) continue;
                  string comment=HistoryDealGetString(deal,DEAL_COMMENT);
                  if(StringFind(comment,"SCP:")==0) { plan_id=StringToInteger(StringSubstr(comment,4)); break; }
                 }
            // Đếm vị thế đã đóng hết, gồm cả dừng/chốt do sàn khớp; chốt một phần không tính.
            if(entry!=DEAL_ENTRY_IN && pid>0 && !PositionSelectByTicket((ulong)pid)) g_closed++;
            g_journal.ExecLine(when,entry==DEAL_ENTRY_IN?"DEAL_IN":"DEAL_OUT",plan_id,
                              "deal="+(string)d+", position="+(string)pid+", price="+DoubleToString(price,8)+
                              ", volume="+DoubleToString(volume,4)+", money="+DoubleToString(net,2));
            HistoryDealSelect(d);
           }
         if(HistoryDealGetInteger(d, DEAL_TYPE) == DEAL_TYPE_BALANCE)
           {
            double amount = HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_COMMISSION);
            g_risk.OnBalance(amount);
            g_journal.ExecLine(TimeCurrent(), "NAP_RUT", 0, "số dư đổi " + DoubleToString(amount, 2));
           }
        }
     }
  }
