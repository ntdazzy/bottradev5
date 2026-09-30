// ScpScenario.mqh — các nhánh vào lệnh độc lập S01..S08 (SPEC mục 8, 9.2, 14).
// Hàm thuần: không đọc MT5, không gửi lệnh.
// Thứ tự ưu tiên khi nhiều nhánh cùng đủ: S06/S07 → S05 → S03 → S08 → S01/S02 → S04 (SPEC 9.2).
#ifndef SCP_SCENARIO_MQH
#define SCP_SCENARIO_MQH

#include "ScpTypes.mqh"
#include "ScpSeries.mqh"
#include "ScpZones.mqh"
#include "ScpEpisodes.mqh"
#include "ScpReaction.mqh"

string ScpReactionWhy(ENUM_SCP_REACTION r)
  {
   switch(r)
     {
      case SCP_RE_P1:
         return "rút râu P1";
      case SCP_RE_P2:
         return "nhấn chìm P2";
      case SCP_RE_P3:
         return "vượt đỉnh/đáy nhỏ P3";
      case SCP_RE_P4:
         return "phá có chuyển động P4";
      case SCP_RE_P5:
         return "kiểm tra lại giữ được P5";
     }
   return "chưa có phản ứng";
  }

// Trạng thái theo dõi một đường EMA cho S08 (đóng băng trong một episode).
struct ScpEmaWatch
  {
   bool              active;
   int               period;
   ENUM_SCP_TF       tf;
   double            frozen;
   double            atr, eps;
   bool              armed;
   datetime          left_bar;
   ENUM_SCP_TF       entry_tf;
   ENUM_SCP_SIDE     side;
   datetime          touch_at;
   double            ext_low, ext_high;
   datetime          deadline;
  };

class ScpScenarioEngine
  {
private:
   ScpEmaWatch       m_ema[18];
   datetime          m_last_close;
   long              m_used_key[256];
   datetime          m_used_time[256];
   int               m_used_count, m_used_head;
   datetime          m_evaluated_m1, m_evaluated_m5;
   ScpProposal       m_batch[256];
   int               m_batch_count;
   double            m_batch_bid;

   bool              Used(long key, datetime t)
     {
      for(int i = 0; i < m_used_count; i++)
         if(m_used_key[i] == key && m_used_time[i] == t) return true;
      return false;
     }


   // ---------------------------------------------------------------- tiện ích

   ENUM_SCP_DIR      LargeDir(ScpFrames &fr)
     {
      ScpSeries *d1 = fr.Get(SCP_TF_D1);
      if(d1 != NULL && (d1.Dir() == SCP_DIR_UP || d1.Dir() == SCP_DIR_DOWN))
         return d1.Dir();
      ScpSeries *h4 = fr.Get(SCP_TF_H4);
      if(h4 != NULL && (h4.Dir() == SCP_DIR_UP || h4.Dir() == SCP_DIR_DOWN))
         return h4.Dir();
      return SCP_DIR_UNDEFINED;
     }

   bool              BarTouched(const ScpBar &b, const ScpZone &z, double eps)
     {
      return (b.h >= z.bottom - eps) && (b.l <= z.top + eps);
     }

   int               BarIndexOf(ScpSeries *s, datetime t)
     {
      for(int b = s.Count() - 1; b >= 0; b--)
         if(s.Bar(b).open_time == t)
            return b;
      return -1;
     }

   bool              FreshBreak(ScpSeries *s, const ScpBreakEvent &b)
     {
      if(s.Count() < 1)
         return false;
      return (s.Bar(s.Count() - 1).open_time == b.bar_time);
     }

   // Phản ứng mới trên nến đã đóng cuối của khung giao dịch.
   ENUM_SCP_REACTION DetectReaction(ScpSeries *s, const ScpZone &z, ScpEpisode &ep, int dir, double eps)
     {
      int n = s.Count();
      if(n < 2)
         return SCP_RE_NONE;
      ScpBar cur = s.Bar(n - 1);
      ScpBar prev = s.Bar(n - 2);
      if(cur.close_time<=ep.touch_at || cur.open_time<z.known_at || ep.touch_at<=m_last_close) return SCP_RE_NONE;
      bool touched_cur = BarTouched(cur, z, eps);
      bool touched_prev = prev.close_time>ep.touch_at && prev.open_time>=z.known_at && BarTouched(prev, z, eps);
      if(ScpP1(cur, dir, z.bottom, z.top, ep.atr_ref, touched_cur))
         return SCP_RE_P1;
      if(ScpP2(prev, cur, dir, z.bottom, z.top, touched_cur || touched_prev))
         return SCP_RE_P2;
      if(ScpP3(cur, dir, ep.pivot_small, eps, true) && dir*(cur.c-(dir>0?z.top:z.bottom))>0)
         return SCP_RE_P3;
      return SCP_RE_NONE;
     }

   void              FillContext(ScpFrames &fr, ScpProposal &p, ENUM_SCP_SCENARIO sc)
     {
      ENUM_SCP_DIR large = LargeDir(fr);
      if(large == SCP_DIR_UNDEFINED)
         p.context = SCP_CTX_UNDEFINED;
      else
         if(large == (ENUM_SCP_DIR)p.direction)
            p.context = SCP_CTX_WITH_LARGE;
         else
            p.context = SCP_CTX_COUNTER_LARGE;
      p.scenario = sc;
     }

   // Mục tiêu: mép cản đối diện gần nhất còn hiệu lực (SPEC 10.3, 14.7).
   bool              PickTarget(ScpZoneMap &zones, double bid, int dir, long own_zone, double eps,
                                long &target_id, double &target_edge, string &why_out)
     {
      ENUM_SCP_ROLE role;
      ENUM_SCP_TF tf;
      double edge = 0.0;
      long id = 0;
      if(!zones.NearestScalpTarget(bid, dir, own_zone, id, edge, role, tf))
        {
         why_out = "không có mục tiêu M1/M5 hoặc đang nằm trong cản đối diện";
         return false;
        }
      target_id = id;
      target_edge = edge;
      why_out = "cản " + ScpTfName(tf) + " tại " + DoubleToString(edge, 3);
      return true;
     }

   // Lắp một đề nghị từ các mảnh đã kiểm.
   bool              Compose(int dir, ENUM_SCP_SCENARIO sc, ENUM_SCP_TF etf, long zone_id, long ep_id,
                             long break_id, ENUM_SCP_THESIS thesis, double inval, double atr_ref,
                             ENUM_SCP_REACTION re, datetime re_time, string why,
                             ScpFrames &fr, ScpZoneMap &zones, const ScpQuote &q, double eps,
                             ScpProposal &out)
     {
      if(etf != SCP_TF_M1 && etf != SCP_TF_M5) return false;
      ScpSeries *entry = fr.Get(etf);
      if(entry == NULL || entry.Count() < 1) return false;
      ScpBar confirmed = entry.LastBar();
      if(re_time != confirmed.known_at || confirmed.open_time <= m_last_close ||
         q.time < re_time || q.time > re_time + 2 || re_time - confirmed.close_time > 2 ||
         (confirmed.received_mono > 0 && (uint)(GetTickCount() - confirmed.received_mono) > 2000)) return false;
      long key = (ep_id > 0 ? ep_id * 100 : (break_id > 0 ? break_id * 100 : zone_id * 100)) + (int)sc;
      if(Used(key, re_time)) return false;
      ZeroMemory(out);
      out.reaction_key = key;
      out.reaction_bid = confirmed.c;
      out.reaction_mono = confirmed.received_mono;
      out.confirmation_edge = confirmed.c - dir * 0.25 * atr_ref;
      out.atr_m1 = fr.Get(SCP_TF_M1).Atr();
      long tid = 0;
      double tedge = 0.0;
      string twhy = "";
      if(!PickTarget(zones, q.bid, dir, zone_id, eps, tid, tedge, twhy))
         return false;
      out.scenario = sc;
      out.zone_id = zone_id;
      out.episode_id = ep_id;
      out.break_id = break_id;
      out.entry_tf = etf;
      out.management_tf = SCP_TF_M1;
      out.direction = dir;
      out.thesis = thesis;
      out.reaction = re;
      out.reaction_known_at = re_time;
      out.provisional = false;
      out.invalidation = inval;
      out.target_zone_id = tid;
      out.target_edge = tedge;
      out.atr_ref = atr_ref;
      out.why = ScpTfName(etf) + " " + why + "; mốc sai " + DoubleToString(inval, 3) + "; mục tiêu " + twhy;
      FillContext(fr, out, sc);
      return true;
     }

   void              AddCandidate(ScpProposal &list[], int &count, ScpProposal &p)
     {
      if(count >= 256)
         return;
      // Bỏ trùng theo (vùng, chiều).
      for(int i = 0; i < count; i++)
         if(list[i].zone_id == p.zone_id && list[i].direction == p.direction)
            return;
      list[count++] = p;
     }

   // ---------------------------------------------------------------- S05/S06/S07

   void              TryBreakBranches(ScpFrames &fr, ScpZoneMap &zones, ScpEpisodeMap &eps,
                                      const ScpQuote &q, ScpProposal &list[], int &count)
     {
      for(int i = 0; i < eps.BreakCount(); i++)
        {
         ScpBreakEvent b = eps.BreakAt(i);
         if(b.consumed || b.failed)
            continue;
         ScpSeries *s = fr.Get(b.break_tf);
         if(s == NULL || !s.Info().data_ok || s.Count() < 3)
            continue;
         ScpZone z;
         if(!zones.Find(b.zone_id, z))
            continue;
         double atr = b.atr_ref>0 ? b.atr_ref : s.Atr();
         double eps_g = b.eps_geom > 0 ? b.eps_geom : SCP_K_BUFFER * s.Atr();
         int idx = BarIndexOf(s, b.bar_time);
         if(idx < 0)
            continue;
         int last = s.Count() - 1;
         int dir = b.direction;
         double edge = b.edge_bid;
         // ---- S05: đi theo cú phá vừa xác nhận, chưa hồi.
         if(b.confirmed && b.is_p4 && b.used_at[SCP_SC_S05] == 0 && FreshBreak(s, b))
           {
            bool still_beyond = (dir > 0) ? (q.bid > edge + eps_g) : (q.bid < edge - eps_g);
            double far = MathAbs(q.bid - b.bar_close);   // đuổi giá so với giá xác nhận (V05)
            if(still_beyond && far <= 0.25 * atr)
              {
               double inval = (dir > 0) ? MathMin(b.bar_low, edge - eps_g) : MathMax(b.bar_high, edge + eps_g);
               ScpProposal p;
               if(Compose(dir, SCP_SC_S05, b.break_tf, z.id, 0, b.id, SCP_THESIS_BREAK_HOLD, inval,
                          atr, SCP_RE_P4, b.known_at,
                          "P4 phá " + DoubleToString(edge, 3) + " còn giữ phía mới",
                          fr, zones, q, eps_g, p))
                  AddCandidate(list, count, p);
              }
           }
         // ---- S06: phá rồi quay lại kiểm tra, giữ được phía mới.
         if(b.confirmed && b.used_at[SCP_SC_S06] == 0 && !FreshBreak(s, b) && last - idx <= 7)
           {
            int retest = -1;
            int invalidated = -1;
            for(int k = idx + 1; k <= last; k++)
              {
               ScpBar bb = s.Bar(k);
               if(bb.open_time < b.known_at)
                  continue;
               double lo_z = edge - eps_g, hi_z = edge + eps_g;
               bool touched = (bb.h >= lo_z && bb.l <= hi_z);
               if(touched && retest < 0 && k - idx <= 5)
                  retest = k;
               bool broke_back = (dir > 0) ? (bb.c < edge - eps_g || bb.l <= b.invalidation) :
                                                    (bb.c > edge + eps_g || bb.h >= b.invalidation);
               if(broke_back && retest >= 0)
                 {
                  invalidated = k;
                  break;
                 }
               if(touched && retest >= 0 && k - retest > 2)
                  break;
              }
            if(retest > 0 && invalidated < 0 && last - retest < 2)
              {
               ScpBar prev = s.Bar(last - 1);
               ScpBar cur = s.Bar(last);
               double small = (dir > 0) ? s.SmallPivot(true, retest, 20, s.Bar(retest).open_time)
                                        : s.SmallPivot(false, retest, 20, s.Bar(retest).open_time);
               bool held = false;
               if(dir > 0)
                  held = ScpP1(cur, +1, edge - eps_g, edge + eps_g, atr, true) ||
                         ScpP2(prev, cur, +1, edge - eps_g, edge + eps_g, true) ||
                         ScpP3(cur, +1, small, eps_g, true);
               else
                  held = ScpP1(cur, -1, edge - eps_g, edge + eps_g, atr, true) ||
                         ScpP2(prev, cur, -1, edge - eps_g, edge + eps_g, true) ||
                         ScpP3(cur, -1, small, eps_g, true);
               // Điều kiện P5 yêu cầu không đóng lại sai phía.
               if(dir > 0 && cur.c < edge - eps_g)
                  held = false;
               if(dir < 0 && cur.c > edge + eps_g)
                  held = false;
               if(held)
                 {
                  eps.SetRole(z.id,b.break_tf,dir);
                  zones.SetHeldRole(z.id,b.break_tf,dir);
                  double inval = (dir > 0) ? MathMin(cur.l, edge - eps_g) : MathMax(cur.h, edge + eps_g);
                  for(int j = retest; j <= last; j++)
                     inval = dir > 0 ? MathMin(inval, s.Bar(j).l) : MathMax(inval, s.Bar(j).h);
                  ScpProposal p;
                  if(Compose(dir, SCP_SC_S06, b.break_tf, z.id, 0, b.id, SCP_THESIS_BREAK_HOLD, inval,
                             atr, SCP_RE_P5, cur.known_at,
                             "kiểm tra lại mép " + DoubleToString(edge, 3) + " giữ được phía mới",
                             fr, zones, q, eps_g, p))
                     AddCandidate(list, count, p);
                 }
              }
           }
         // ---- S07: xuyên qua rồi lấy lại phía cũ trong tối đa 2 nến.
         if(b.used_at[SCP_SC_S07] == 0 && idx >= 0 && last >= idx && last - idx <= 2)
           {
            ScpBar cur = s.Bar(last);
            ScpBar prev = s.Bar(last - 1);
            double sweep_low = s.Bar(idx).l, sweep_high = s.Bar(idx).h;
            for(int k = idx + 1; k <= last; k++)
              {
               sweep_low = MathMin(sweep_low, s.Bar(k).l);
               sweep_high = MathMax(sweep_high, s.Bar(k).h);
              }
            if(dir > 0)
              {
               bool swept = (sweep_high > edge + eps_g);
               bool reclaimed = (cur.c < edge - eps_g);
               ENUM_SCP_REACTION re_down=ScpReactionAt(prev,cur,-1,edge-eps_g,edge+eps_g,atr,eps_g,
                  s.SmallPivot(false,idx,20,b.known_at),true);
               if(swept && reclaimed && re_down!=SCP_RE_NONE)
                 {
                  ScpProposal p;
                  double inval = MathMax(sweep_high, edge + eps_g);
                  if(Compose(-1, SCP_SC_S07, b.break_tf, z.id, 0, b.id, SCP_THESIS_LOCAL_REACTION, inval,
                             atr, re_down, cur.known_at,
                             "xuyên " + DoubleToString(edge, 3) + " rồi lấy lại phía cũ",
                             fr, zones, q, eps_g, p))
                     AddCandidate(list, count, p);
                 }
              }
            else
              {
               bool swept = (sweep_low < edge - eps_g);
               bool reclaimed = (cur.c > edge + eps_g);
               ENUM_SCP_REACTION re_up=ScpReactionAt(prev,cur,1,edge-eps_g,edge+eps_g,atr,eps_g,
                  s.SmallPivot(true,idx,20,b.known_at),true);
               if(swept && reclaimed && re_up!=SCP_RE_NONE)
                 {
                  ScpProposal p;
                  double inval = MathMin(sweep_low, edge - eps_g);
                  if(Compose(+1, SCP_SC_S07, b.break_tf, z.id, 0, b.id, SCP_THESIS_LOCAL_REACTION, inval,
                             atr, re_up, cur.known_at,
                             "xuyên " + DoubleToString(edge, 3) + " rồi lấy lại phía cũ",
                             fr, zones, q, eps_g, p))
                     AddCandidate(list, count, p);
                 }
              }
           }
        }
     }

   // ---------------------------------------------------------------- S03 hồi nông

   void              TryImpulse(ScpFrames &fr, ScpZoneMap &zones, ScpEpisodeMap &eps,
                                const ScpQuote &q, ScpProposal &list[], int &count)
     {
      for(int i = 0; i < eps.BreakCount(); i++)
        {
         ScpBreakEvent b = eps.BreakAt(i);
         if(b.consumed || b.failed || !b.is_p4 || !b.confirmed || b.used_at[SCP_SC_S03] != 0)
            continue;
         ScpSeries *s = fr.Get(b.break_tf);
         if(s == NULL || !s.Info().data_ok || s.Count() < 5)
            continue;
         int idx = BarIndexOf(s, b.bar_time);
         if(idx < 0)
            continue;
         int dir = b.direction;
         if(s.Dir() != (ENUM_SCP_DIR)dir)
            continue;
         double start = (dir > 0) ? s.SmallPivot(false, idx, 20, b.known_at)
                                  : s.SmallPivot(true, idx, 20, b.known_at);
         if(start <= 0.0)
            continue;
         double end = (dir > 0) ? b.bar_high : b.bar_low;
         double length = MathAbs(end - start);
         if(length <= 0.0)
            continue;
         double extreme = q.bid;
         for(int k = idx + 1; k < s.Count(); k++)
            extreme = dir > 0 ? MathMin(extreme, s.Bar(k).l) : MathMax(extreme, s.Bar(k).h);
         double retrace = (dir > 0) ? (end - extreme) : (extreme - end);
         if(retrace <= 0.0 || retrace > 0.5 * length)
            continue;   // chưa hồi hoặc hồi quá sâu thì không còn là hồi nông
         // Vùng nhỏ đã biết nằm trong nửa sau của đoạn đẩy (SPEC 8 S03, 14.5).
         double eps_g = SCP_K_BUFFER * s.Atr();
         double mid = (dir > 0) ? (start + 0.5 * length) : (start - 0.5 * length);
         long small_id = 0;
         double sz_lo = 0.0, sz_hi = 0.0;
         for(int zi = 0; zi < zones.Count(); zi++)
           {
            ScpZone zn = zones.At(zi);
            if(!zn.alive || zn.source_tf != b.break_tf)
               continue;
            if(zn.known_at > b.known_at)
               continue;   // vùng nhỏ phải đã biết trước lúc phá
            if(dir > 0)
              {
               if(zn.source_role != SCP_ROLE_SUPPORT)
                  continue;
               if(!(zn.bottom >= mid - eps_g && zn.top <= end + eps_g))
                  continue;
               if(small_id == 0 || zn.bottom > sz_lo)
                 {
                  small_id = zn.id;
                  sz_lo = zn.bottom;
                  sz_hi = zn.top;
                 }
              }
            else
              {
               if(zn.source_role != SCP_ROLE_RESISTANCE)
                  continue;
               if(!(zn.top <= mid + eps_g && zn.bottom >= end - eps_g))
                  continue;
               if(small_id == 0 || zn.top < sz_hi)
                 {
                  small_id = zn.id;
                  sz_lo = zn.bottom;
                  sz_hi = zn.top;
                 }
              }
           }
         if(small_id == 0)
            continue;
         ScpBar cur = s.Bar(s.Count() - 1);
         ScpBar prev = s.Bar(s.Count() - 2);
         bool touched = (cur.h >= sz_lo - eps_g && cur.l <= sz_hi + eps_g) ||
                        (prev.h >= sz_lo - eps_g && prev.l <= sz_hi + eps_g);
         if(!touched)
            continue;
         bool re = false;
         if(dir > 0)
            re = ScpP1(cur, +1, sz_lo, sz_hi, s.Atr(), true) ||
                 ScpP2(prev, cur, +1, sz_lo, sz_hi, true) ||
                 ScpP3(cur, +1, s.SmallPivot(true, s.Count() - 1, 20, cur.known_at), eps_g, true);
         else
            re = ScpP1(cur, -1, sz_lo, sz_hi, s.Atr(), true) ||
                 ScpP2(prev, cur, -1, sz_lo, sz_hi, true) ||
                 ScpP3(cur, -1, s.SmallPivot(false, s.Count() - 1, 20, cur.known_at), eps_g, true);
         if(!re)
            continue;
         double inval = cur.l;
         if(dir < 0)
            inval = cur.h;
         for(int k = idx + 1; k <= s.Count() - 1; k++)
           {
            if(dir > 0)
               inval = MathMin(inval, s.Bar(k).l);
            else
               inval = MathMax(inval, s.Bar(k).h);
           }
         ScpProposal p;
         if(Compose(dir, SCP_SC_S03, b.break_tf, b.zone_id, 0, b.id, SCP_THESIS_LOCAL_REACTION, inval,
                    s.Atr(), SCP_RE_P1, cur.known_at,
                    "hồi nông về vùng nhỏ sau nhịp đẩy " + DoubleToString(start, 3) + "→" + DoubleToString(end, 3),
                    fr, zones, q, eps_g, p))
            AddCandidate(list, count, p);
        }
     }

   // ---------------------------------------------------------------- S04 đi ngang

   void              TryRange(ScpFrames &fr, ScpZoneMap &zones, const ScpQuote &q,
                              ScpProposal &list[], int &count)
     {
      for(int tfi = 0; tfi < 2; tfi++)
        {
         ScpSeries *s = fr.Get(tfi);
         if(s == NULL || !s.Info().data_ok || s.Count() < 22)
            continue;
         double eps_g = SCP_K_BUFFER * s.Atr();
         int last = s.Count() - 1;
         int first = MathMax(0, last - 19);
         // Gom pivot đã xác nhận trong cửa sổ theo dung sai.
         double highs[40], lows[40];
         datetime high_t[40], low_t[40];
         int nh = 0, nl = 0;
         for(int i = 0; i < s.PivotCount(); i++)
           {
            ScpPivot p = s.Pivot(i);
            if(p.ambiguous)
               continue;
            int b = BarIndexOf(s, p.bar_time);
            if(b < first || b > last)
               continue;
            if(p.is_high && nh < 40)
              {
               highs[nh] = p.price;
               high_t[nh] = p.bar_time;
               nh++;
              }
            else
               if(!p.is_high && nl < 40)
                 {
                  lows[nl] = p.price;
                  low_t[nl] = p.bar_time;
                  nl++;
                 }
           }
         if(nh < 2 || nl < 2)
            continue;
         // Cụm biên trên và dưới: cần ít nhất 2 lần chạm cách nhau >= 2 nến.
         double upper = 0.0, lower = 0.0;
         bool up_ok = false, lo_ok = false;
         for(int i = 0; i < nh && !up_ok; i++)
            for(int j = i + 1; j < nh; j++)
              {
               if(MathAbs(highs[i] - highs[j]) > eps_g)
                  continue;
               if(MathAbs((long)high_t[i] - (long)high_t[j]) < 2 * PeriodSeconds(SCP_TF_PERIODS[tfi]))
                  continue;
               upper = MathMax(highs[i], highs[j]);
               up_ok = true;
               break;
              }
         for(int i = 0; i < nl && !lo_ok; i++)
            for(int j = i + 1; j < nl; j++)
              {
               if(MathAbs(lows[i] - lows[j]) > eps_g)
                  continue;
               if(MathAbs((long)low_t[i] - (long)low_t[j]) < 2 * PeriodSeconds(SCP_TF_PERIODS[tfi]))
                  continue;
               lower = MathMin(lows[i], lows[j]);
               lo_ok = true;
               break;
              }
         if(!up_ok || !lo_ok || !(lower < upper))
            continue;
         // Chưa có đóng phá biên.
         bool broken = false;
         for(int b = first; b <= last; b++)
           {
            ScpBar bb = s.Bar(b);
            if(bb.c > upper + eps_g || bb.c < lower - eps_g)
              {
               broken = true;
               break;
              }
           }
         if(broken)
            continue;
         double width = upper - lower;
         if(width <= 0.0)
            continue;
         double pos = (q.bid - lower) / width;
         ScpBar cur = s.Bar(last);
         ScpBar prev = s.Bar(last - 1);
         int dir = 0;
         if(pos <= 0.25)
            dir = +1;
         else
            if(pos >= 0.75)
               dir = -1;
         if(dir == 0)
            continue;   // giữa vùng đi ngang: không vào
         double edge = (dir > 0) ? lower : upper;
         bool re = false;
         if(dir > 0)
            re = ScpP1(cur, +1, lower - eps_g, lower + eps_g, s.Atr(), cur.l <= lower + eps_g) ||
                 ScpP2(prev, cur, +1, lower - eps_g, lower + eps_g, cur.l <= lower + eps_g || prev.l <= lower + eps_g);
         else
            re = ScpP1(cur, -1, upper - eps_g, upper + eps_g, s.Atr(), cur.h >= upper - eps_g) ||
                 ScpP2(prev, cur, -1, upper - eps_g, upper + eps_g, cur.h >= upper - eps_g || prev.h >= upper - eps_g);
         if(!re)
            continue;
         double inval = 0.0;
         if(dir > 0)
           {
            inval = lower - eps_g;
            for(int b = MathMax(first, last - 5); b <= last; b++)
               inval = MathMin(inval, s.Bar(b).l);
           }
         else
           {
            inval = upper + eps_g;
            for(int b = MathMax(first, last - 5); b <= last; b++)
               inval = MathMax(inval, s.Bar(b).h);
           }
         ScpProposal p;
         if(Compose(dir, SCP_SC_S04, (ENUM_SCP_TF)tfi, 0, 0, 0, SCP_THESIS_LOCAL_REACTION, inval,
                    s.Atr(), SCP_RE_P1, cur.known_at,
                    "phản ứng tại biên " + DoubleToString(edge, 3) + " của phạm vi " +
                    DoubleToString(lower, 3) + "-" + DoubleToString(upper, 3),
                    fr, zones, q, eps_g, p))
            AddCandidate(list, count, p);
        }
     }

   // ---------------------------------------------------------------- S08 EMA đa khung

   void              TryEma(ScpFrames &fr, ScpZoneMap &zones, const ScpQuote &q,
                            ScpProposal &list[], int &count)
     {
      int periods[3] = {20,50,200};
      ENUM_SCP_TF tfs[3] = {SCP_TF_M5,SCP_TF_M15,SCP_TF_H1};
      for(int e = 0; e < 2; e++)
       for(int ti = 0; ti < 3; ti++)
        for(int pi = 0; pi < 3; pi++)
         {
          int k = e * 9 + ti * 3 + pi;
          ScpSeries *src = fr.Get(tfs[ti]);
          ScpSeries *s = fr.Get(e);
          if(src == NULL || s == NULL || !src.EmaReady(periods[pi]) || !s.Info().data_ok) continue;
          ScpBar cur = s.LastBar(), prev = s.Bar(s.Count()-2);
          double ema = src.Ema(periods[pi],src.Count()-1);
          double eg = SCP_K_BUFFER * s.Atr();
          if(!m_ema[k].active)
            {
             if(q.bid > ema + eg || q.bid < ema - eg)
               {
                m_ema[k].armed = true;
                m_ema[k].side = q.bid > ema ? SCP_SIDE_ABOVE : SCP_SIDE_BELOW;
               }
             else if(m_ema[k].armed && cur.open_time > m_last_close)
               {
                m_ema[k].active = true; m_ema[k].armed = false;
                m_ema[k].frozen = ema; m_ema[k].eps = eg; m_ema[k].atr = s.Atr();
                m_ema[k].touch_at = q.time;
                m_ema[k].deadline = q.time + 2 * PeriodSeconds(SCP_TF_PERIODS[e]);
                m_ema[k].ext_low = q.bid; m_ema[k].ext_high = q.bid;
               }
             continue;
            }
          m_ema[k].ext_low = MathMin(m_ema[k].ext_low,q.bid);
          m_ema[k].ext_high = MathMax(m_ema[k].ext_high,q.bid);
          double ef = m_ema[k].frozen, epsf = m_ema[k].eps;
          if(q.time > m_ema[k].deadline)
            {
             if(cur.close_time > m_ema[k].touch_at && (cur.l > ef+epsf || cur.h < ef-epsf))
                { m_ema[k].active=false; m_ema[k].armed=false; }
             continue;
            }
          if(cur.close_time <= m_ema[k].touch_at) continue;
          int dir = m_ema[k].side == SCP_SIDE_ABOVE ? 1 : -1;
          double lo = ef-epsf, hi=ef+epsf;
          bool touched = cur.l <= hi && cur.h >= lo;
          bool pair_touch=touched || (prev.l<=hi && prev.h>=lo && prev.close_time > m_ema[k].touch_at);
          ENUM_SCP_REACTION re=ScpReactionAt(prev,cur,dir,lo,hi,m_ema[k].atr,epsf,0,pair_touch);
          if(re==SCP_RE_NONE) continue;
          double inval = dir>0 ? MathMin(cur.l,m_ema[k].ext_low) : MathMax(cur.h,m_ema[k].ext_high);
          ScpProposal p;
          if(Compose(dir,SCP_SC_S08,(ENUM_SCP_TF)e,-100-k,0,0,SCP_THESIS_LOCAL_REACTION,
                     inval,m_ema[k].atr,re,cur.known_at,
                     "phản ứng EMA"+IntegerToString(periods[pi])+" "+ScpTfName(tfs[ti]),
                     fr,zones,q,epsf,p))
            {
             p.confirmation_edge = dir>0 ? hi : lo;
             AddCandidate(list,count,p);
            }
         }
     }

public:
                     ScpScenarioEngine() { Init(); }
   void              Init()
     {
      for(int i = 0; i < 18; i++) ZeroMemory(m_ema[i]);
      m_used_count=0; m_used_head=0; m_last_close=0;
      m_evaluated_m1=0; m_evaluated_m5=0; m_batch_count=0; m_batch_bid=0;
     }

   void OnClosed(datetime t)
     {
      if(t<=m_last_close) return;
      m_last_close=t;
      for(int i=0;i<18;i++) if(m_ema[i].active) m_ema[i].deadline=t-1;
     }
   // planned=false: kế hoạch bị loại (mục tiêu gần, tỷ lệ thấp...). Chỉ khóa đúng phản ứng này,
   // để nến phản ứng mới trong cùng lần chạm/cửa sổ phá vẫn được xét (SPEC 6.3: một xác nhận chỉ một lần gửi).
   void Consume(const ScpProposal &p, ScpEpisodeMap &episodes, ScpZoneMap &zones, bool planned = true)
     {
      if(p.scenario==SCP_SC_S06)
        { episodes.SetRole(p.zone_id,p.entry_tf,p.direction); zones.SetHeldRole(p.zone_id,p.entry_tf,p.direction); }
      m_used_key[m_used_head] = p.reaction_key;
      m_used_time[m_used_head] = p.reaction_known_at;
      m_used_head=(m_used_head+1)%256; if(m_used_count<256) m_used_count++;
      int i=-1;
      if(p.episode_id>0 && episodes.ByIdWritable(p.episode_id,i))
        {
         if(planned) episodes.ConsumeReaction(i,p.reaction_known_at,p.reaction);
         else episodes.SeenReaction(i,p.reaction_known_at);
         zones.RegisterReaction(p.zone_id,episodes.At(i).cluster_id);
        }
      if(p.break_id>0 && planned) episodes.ConsumeBreak(p.break_id,(int)p.scenario,p.reaction_known_at);
     }

   // EA được thử kế hoạch tiếp theo nếu đề nghị đầu không đạt hoặc chưa bật nhánh.
   bool Next(ScpProposal &out)
     {
      if(m_batch_count==0) return false;
      int best=0;
      for(int i=1;i<m_batch_count;i++)
        {
         double room=m_batch[i].direction*(m_batch[i].target_edge-m_batch_bid);
         double bestroom=m_batch[best].direction*(m_batch[best].target_edge-m_batch_bid);
         if(m_batch[i].reaction_known_at>m_batch[best].reaction_known_at ||
            (m_batch[i].reaction_known_at==m_batch[best].reaction_known_at && room>bestroom)) best=i;
        }
      out=m_batch[best];
      for(int i=best;i<m_batch_count-1;i++) m_batch[i]=m_batch[i+1];
      m_batch_count--;
      return true;
     }

   // Chạy tất cả nhánh hiện có. Trả về true nếu có đề nghị; `conflict_note` khác rỗng khi hai chiều cùng đủ.
   bool              Run(ScpFrames &fr, ScpZoneMap &zones, ScpEpisodeMap &eps,
                         const ScpQuote &q, ScpProposal &out, string &conflict_note)
     {
      conflict_note = "";
      m_batch_count=0; m_batch_bid=q.bid;
      ScpProposal cand[256];
      int nc = 0;
      // Chỉ theo dõi tiếp cận EMA trên từng tick. Các mẫu đóng nến xét một lần/nến.
      TryEma(fr,zones,q,cand,nc);
      datetime m1=fr.Get(SCP_TF_M1).Info().last_closed_at;
      datetime m5=fr.Get(SCP_TF_M5).Info().last_closed_at;
      if(m1==m_evaluated_m1 && m5==m_evaluated_m5) return false;
      m_evaluated_m1=m1; m_evaluated_m5=m5;
      // ---- S06, S07, S05 trước (nhánh sự kiện cụ thể), rồi S03, S08, S04.
      TryBreakBranches(fr, zones, eps, q, cand, nc);
      TryImpulse(fr, zones, eps, q, cand, nc);
      TryRange(fr, zones, q, cand, nc);
      // ---- S01/S02 cho các episode đang chờ phản ứng.
      for(int i = 0; i < eps.Count(); i++)
        {
         ScpEpisode ep = eps.At(i);
         if(ep.state != SCP_EP_WAIT_REACTION && ep.state != SCP_EP_TOUCHED)
            continue;
         ScpZone z;
         if(!zones.Find(ep.zone_id, z) || !z.alive)
            continue;
         z.bottom = ep.zone_bottom; z.top = ep.zone_top;
         ScpSeries *s = fr.Get(ep.entry_tf);
         if(s == NULL)
            continue;
         double eps_g = MathMax(ep.eps_geom, 0.0);
         ENUM_SCP_DIR local = s.Dir();
         ENUM_SCP_DIR large = LargeDir(fr);
         int dir = (ep.local_role == SCP_ROLE_SUPPORT) ? +1 : -1;
         ENUM_SCP_SCENARIO sc = SCP_SC_NONE;
         // S01: thuận nhịp M1/M5, hoặc thuận hướng lớn khi nhịp nhỏ đang hồi ngược về vùng (SPEC 8 S01).
         if(large != SCP_DIR_UNDEFINED && (int)large == -dir)
            sc = SCP_SC_S02;
         else
            if(local == (ENUM_SCP_DIR)dir || (large != SCP_DIR_UNDEFINED && (int)large == dir))
               sc = SCP_SC_S01;
            else
               continue;
         ENUM_SCP_REACTION re = DetectReaction(s, z, ep, dir, eps_g);
         if(re == SCP_RE_NONE)
            continue;
         ScpBar last = s.Bar(s.Count() - 1);
         if(last.known_at <= ep.reaction_at)
            continue;
         double inval = (dir > 0) ? ep.ext_low : ep.ext_high;
         if(inval <= 0.0)
            continue;
         ScpProposal p;
         if(!Compose(dir, sc, ep.entry_tf, z.id, ep.id, 0, SCP_THESIS_LOCAL_REACTION, inval,
                     ep.atr_ref, re, last.known_at,
                     ScpReactionWhy(re) + " tại vùng " + DoubleToString(z.bottom, 3) + "-" +
                     DoubleToString(z.top, 3) + " (" + ScpTfName(z.source_tf) + ")",
                     fr, zones, q, eps_g, p))
            continue;
         p.confirmation_edge = dir > 0 ? z.top : z.bottom;
         AddCandidate(cand, nc, p);
        }
      if(nc == 0)
         return false;
      // Chỉ đối nghịch cùng một vùng/sự kiện mới phải chờ chung.
      for(int i=0;i<nc;i++)
         for(int j=i+1;j<nc;j++)
            if(cand[i].zone_id==cand[j].zone_id && cand[i].direction!=cand[j].direction)
              { conflict_note="hai chiều cùng vùng chưa phân định"; return false; }
      for(int i=0;i<nc;i++) m_batch[m_batch_count++]=cand[i];
      return Next(out);

     }
  };

#endif // SCP_SCENARIO_MQH
