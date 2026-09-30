// ScpEpisodes.mqh — theo dõi lần tiếp cận vùng, episode và sự kiện phá (SPEC mục 6).
// Không đọc MT5, không gửi lệnh. Bên gọi đưa vào giá hiện tại và nến đã đóng của khung giao dịch.
#ifndef SCP_EPISODES_MQH
#define SCP_EPISODES_MQH

#include "ScpTypes.mqh"
#include "ScpZones.mqh"
#include "ScpReaction.mqh"

#define SCP_MAX_EPISODES 256
#define SCP_MAX_BREAKS   256
#define SCP_MAX_WATCH    4096
#define SCP_WATCH_MAP    65536 // bảng tra (vùng,khung) -> chỉ số; luôn kiểm lại

struct ScpWatch
  {
   long              zone_id;
   ENUM_SCP_TF       tf;
   ENUM_SCP_ROLE     role;
   int               approach_side;   // ENUM_SCP_SIDE, 0 là chưa rõ
   double            low_seen, high_seen;
   bool              inside;
   datetime          left_at;         // nến E đóng hoàn toàn rời vùng gần nhất
   datetime          last_touch;
   bool              armed;           // đang theo dõi tiếp cận từ phía hợp lệ
  };

class ScpEpisodeMap
  {
private:
   ScpEpisode        m_ep[SCP_MAX_EPISODES];
   int               m_count;
   long              m_next_ep;
   ScpBreakEvent     m_br[SCP_MAX_BREAKS];
   int               m_break_count;
   long              m_next_break;
   ScpWatch          m_w[SCP_MAX_WATCH];
   int               m_wcount;
   long              m_next_cluster;
   int               m_watch_dropped;
   int               m_wmap[SCP_WATCH_MAP];

   int               WKey(long zone_id, ENUM_SCP_TF tf) { return (int)((zone_id * 8 + (long)tf) % SCP_WATCH_MAP); }

   int               WatchIndex(long zone_id, ENUM_SCP_TF tf)
     {
      int k = (zone_id > 0) ? WKey(zone_id, tf) : -1;
      if(k >= 0)
        {
         int j = m_wmap[k];
         if(j >= 0 && j < m_wcount && m_w[j].zone_id == zone_id && m_w[j].tf == tf)
            return j;
        }
      for(int i = 0; i < m_wcount; i++)
         if(m_w[i].zone_id == zone_id && m_w[i].tf == tf)
           {
            if(k >= 0) m_wmap[k] = i;
            return i;
           }
      if(m_wcount >= SCP_MAX_WATCH)
        {
         m_watch_dropped++;
         return -1;
        }
      m_w[m_wcount].zone_id = zone_id;
      m_w[m_wcount].tf = tf;
      m_w[m_wcount].role = SCP_ROLE_NEUTRAL;
      m_w[m_wcount].approach_side = 0;
      m_w[m_wcount].low_seen = 0.0;
      m_w[m_wcount].high_seen = 0.0;
      m_w[m_wcount].inside = false;
      m_w[m_wcount].left_at = 0;
      m_w[m_wcount].last_touch = 0;
      m_w[m_wcount].armed = false;
      m_wcount++;
      if(k >= 0) m_wmap[k] = m_wcount - 1;
      return m_wcount - 1;
     }

public:
                     ScpEpisodeMap()
     {
      m_count = 0;
      m_next_ep = 1;
      m_break_count = 0;
      m_next_break = 1;
      m_wcount = 0;
      m_next_cluster = 1;
      m_watch_dropped = 0;
      ArrayInitialize(m_wmap, -1);
     }

   void              Init() { m_count = 0; m_next_ep = 1; m_break_count = 0; m_next_break = 1; m_wcount = 0; m_next_cluster = 1; ArrayInitialize(m_wmap, -1); }
   int               WatchDropped() { return m_watch_dropped; }

   int               Count() { return m_count; }
   ScpEpisode        At(int i) { return m_ep[i]; }

   bool              ById(long id, ScpEpisode &out)
     {
      for(int i = 0; i < m_count; i++)
         if(m_ep[i].id == id)
           {
            out = m_ep[i];
            return true;
           }
      return false;
     }

   bool              ByIdWritable(long id, int &index)
     {
      for(int i = 0; i < m_count; i++)
         if(m_ep[i].id == id)
           {
            index = i;
            return true;
           }
      index = -1;
      return false;
     }

   int               FindActive(long zone_id, ENUM_SCP_TF tf)
     {
      for(int i = 0; i < m_count; i++)
        {
         if(m_ep[i].zone_id != zone_id)
            continue;
         if(tf != SCP_TF_COUNT && m_ep[i].entry_tf != tf)
            continue;
         if(m_ep[i].state == SCP_EP_EXPIRED || m_ep[i].state == SCP_EP_CANCELLED)
            continue;
         return i;
        }
      return -1;
     }

   // Phía tiếp cận hợp lệ: hỗ trợ phải đi từ trên xuống, kháng cự từ dưới lên (SPEC 14.3).
   bool              ValidApproach(const ScpZone &z, int side)
     {
      if(z.source_role == SCP_ROLE_SUPPORT)
         return (side == (int)SCP_SIDE_ABOVE);
      if(z.source_role == SCP_ROLE_RESISTANCE)
         return (side == (int)SCP_SIDE_BELOW);
      return false;
     }

   // Theo dõi tiếp cận. Trả về id episode mới nếu giá chạm vùng lần này (0 là chưa).
   // `side` hợp lệ: mua ở hỗ trợ phải tiếp cận từ trên; bán ở kháng cự từ dưới.
   long              Watch(const ScpZone &z, double bid, double eps, datetime now,
                           ENUM_SCP_TF tf, double atr_ref, datetime order_closed_at,
                           double pivot_high_small, double pivot_low_small)
     {
      int wi = WatchIndex(z.id, tf);
      if(wi < 0)
         return 0;
      ScpZone local = z;
      if(m_w[wi].role != SCP_ROLE_NEUTRAL) local.source_role=m_w[wi].role;
      else if((z.source_role==SCP_ROLE_SUPPORT && z.broken_down) ||
              (z.source_role==SCP_ROLE_RESISTANCE && z.broken_up)) return 0;
      double lo_edge = z.bottom - eps;
      double hi_edge = z.top + eps;
      bool inside = (bid >= lo_edge && bid <= hi_edge);
      if(!inside)
        {
         int side = (bid > hi_edge) ? (int)SCP_SIDE_ABOVE : (int)SCP_SIDE_BELOW;
         if(m_w[wi].approach_side != side)
           {
            m_w[wi].approach_side = side;
            m_w[wi].low_seen = bid;
            m_w[wi].high_seen = bid;
           }
         else
           {
            if(bid < m_w[wi].low_seen)
               m_w[wi].low_seen = bid;
            if(bid > m_w[wi].high_seen)
               m_w[wi].high_seen = bid;
           }
         m_w[wi].armed = ValidApproach(local, side);
         m_w[wi].inside = false;
         return 0;
        }
      // Giá đang trong vùng dung sai.
      if(!m_w[wi].armed || !ValidApproach(local, m_w[wi].approach_side) || !z.alive)
        {
         m_w[wi].inside = true;
         return 0;
        }
      int active = FindActive(z.id, tf);
      bool rearm_ok = (m_w[wi].last_touch==0 || m_w[wi].left_at>m_w[wi].last_touch);
      if(active >= 0)
         rearm_ok = rearm_ok && (m_w[wi].left_at > m_ep[active].touch_at && m_w[wi].left_at > order_closed_at);
      else
         rearm_ok = rearm_ok && ((m_w[wi].left_at > order_closed_at) || (order_closed_at == 0));
      if(!rearm_ok)
        {
         m_w[wi].inside = true;
         return 0;
        }
      if(active >= 0) m_ep[active].state=SCP_EP_EXPIRED;
      long id = Open(local, (ENUM_SCP_SIDE)m_w[wi].approach_side, tf, atr_ref, eps, now, bid,
                     pivot_high_small, pivot_low_small);
      m_w[wi].inside = true;
      m_w[wi].last_touch = now;
      m_w[wi].armed = false;
      m_w[wi].left_at = 0;
      return id;
     }

   long              Open(const ScpZone &z, ENUM_SCP_SIDE side, ENUM_SCP_TF tf,
                          double atr_ref, double eps, datetime now, double bid,
                          double pivot_high_small, double pivot_low_small)
     {
      ScpEpisode e;
      e.id = m_next_ep++;
      e.zone_id = z.id;
      e.entry_tf = tf;
      e.state = SCP_EP_WAIT_REACTION;
      e.approach_side = side;
      e.local_role = (side == SCP_SIDE_ABOVE) ? SCP_ROLE_SUPPORT : SCP_ROLE_RESISTANCE;
      e.role_version = 1;
      e.touch_at = now;
      e.opened_at = now;
      int sec = PeriodSeconds(SCP_TF_PERIODS[tf]);
      e.deadline = (datetime)((long)now / sec * sec + sec * 2);
      e.last_event_at = now;
      e.atr_ref = atr_ref;
      e.eps_geom = eps;
      e.zone_bottom = z.bottom;
      e.zone_top = z.top;
      e.ext_low = bid;
      e.ext_high = bid;
      e.invalidation = 0.0;
      e.pivot_small = (side == SCP_SIDE_ABOVE) ? pivot_high_small : pivot_low_small;
      e.small_is_high = (side == SCP_SIDE_ABOVE);
      e.edge_touched = (side == SCP_SIDE_ABOVE) ? z.top : z.bottom;
      e.frozen = true;
      e.last_reaction = SCP_RE_NONE;
      e.reaction_at = 0;
      e.last_break_id = 0;
      e.provisional = false;
      // Gom cụm cùng sự kiện giữa M1/M5.
      e.cluster_id = 0;
      for(int i = 0; i < m_count; i++)
        {
         if(m_ep[i].zone_id != z.id)
            continue;
         if(m_ep[i].state == SCP_EP_EXPIRED || m_ep[i].state == SCP_EP_CANCELLED)
            continue;
         if(MathAbs((long)m_ep[i].touch_at - (long)now) <= 2 * 60)
           {
            e.cluster_id = m_ep[i].cluster_id;
            break;
           }
        }
      if(e.cluster_id == 0)
         e.cluster_id = m_next_cluster++;
      if(m_count >= SCP_MAX_EPISODES)
        {
         for(int i = 0; i < m_count; i++)
           {
            if(m_ep[i].state == SCP_EP_EXPIRED || m_ep[i].state == SCP_EP_CANCELLED)
              {
               m_ep[i] = e;
               return e.id;
              }
           }
         return 0;
        }
      m_ep[m_count++] = e;
      return e.id;
     }

   // Cập nhật cực trị đã thấy và mốc vô hiệu trong episode (gọi mỗi tick khi episode đang mở).
   void              OnTick(int i, double bid)
     {
      if(m_ep[i].state != SCP_EP_WAIT_REACTION && m_ep[i].state != SCP_EP_TOUCHED) return;
      if(bid < m_ep[i].ext_low)
         m_ep[i].ext_low = bid;
      if(bid > m_ep[i].ext_high)
         m_ep[i].ext_high = bid;
     }

   // Thứ tự: cực trị đã thấy -> xuyên phía đối diện -> phản ứng. Không gọi bật là phá.
   void              OnBarClosed(int tf_index, const ScpBar &bar, ScpZoneMap &zones, double eps, datetime now)
     {
      // Lần theo dõi hết hạn vẫn phải nhận biết một lần rời mới sau khi vị thế đã đóng.
      for(int w=0;w<m_wcount;w++)
        {
         if(m_w[w].tf!=(ENUM_SCP_TF)tf_index) continue;
         ScpZone z;
         if(!zones.Find(m_w[w].zone_id,z) || !z.alive || bar.open_time<z.known_at) continue;
         if(bar.l>z.top+eps || bar.h<z.bottom-eps) m_w[w].left_at=bar.close_time;
        }
      for(int i = 0; i < m_count; i++)
        {
         if(m_ep[i].entry_tf != (ENUM_SCP_TF)tf_index) continue;
         if(m_ep[i].state == SCP_EP_EXPIRED || m_ep[i].state == SCP_EP_CANCELLED) continue;
         ScpZone z;
         if(!zones.Find(m_ep[i].zone_id, z)) continue;
         if(bar.open_time < z.known_at || bar.close_time <= m_ep[i].touch_at) continue;
         // Nến chạm có thể bắt đầu trước tick chạm: chỉ bổ sung OHLC khi cả nến đã biết.
         if(m_ep[i].state == SCP_EP_WAIT_REACTION || m_ep[i].state == SCP_EP_TOUCHED)
           {
            m_ep[i].ext_low = MathMin(m_ep[i].ext_low, bar.l);
            m_ep[i].ext_high = MathMax(m_ep[i].ext_high, bar.h);
           }
         double e = m_ep[i].eps_geom;
         int dir = (m_ep[i].approach_side == SCP_SIDE_BELOW) ? +1 : -1;
         double edge = dir > 0 ? m_ep[i].zone_top : m_ep[i].zone_bottom;
         bool crossed = dir > 0 ? bar.h > edge + e : bar.l < edge - e;
         bool confirmed = ScpB0(bar, dir, edge, e);
         if(crossed && m_ep[i].last_break_id == 0)
           {
            long id = Record(z.id, (ENUM_SCP_TF)tf_index, dir, bar.open_time, bar.known_at,
                             edge, confirmed && ScpP4(bar, dir, edge, m_ep[i].atr_ref, e),
                             dir > 0 ? bar.l : bar.h, bar.l, bar.h, bar.c);
            for(int j = 0; j < m_break_count; j++)
               if(m_br[j].id == id)
                 {
                  m_br[j].confirmed = confirmed;
                  m_br[j].atr_ref = m_ep[i].atr_ref;
                  m_br[j].eps_geom = e;
                 }
            m_ep[i].last_break_id = id;
            if(confirmed)
               m_ep[i].state = SCP_EP_BREAK_CONFIRMED;
           }
         if(m_ep[i].last_break_id > 0)
           {
            for(int j = 0; j < m_break_count; j++)
              {
               if(m_br[j].id != m_ep[i].last_break_id || m_br[j].confirmed || !confirmed) continue;
               m_br[j].confirmed = true;
               m_br[j].bar_time = bar.open_time; m_br[j].known_at = bar.known_at;
               m_br[j].bar_low = bar.l; m_br[j].bar_high = bar.h; m_br[j].bar_close = bar.c;
               m_br[j].is_p4 = ScpP4(bar, dir, edge, m_ep[i].atr_ref, e);
               m_ep[i].state = SCP_EP_BREAK_CONFIRMED;
              }
           }
         bool fully_left = (bar.l > m_ep[i].zone_top + e) || (bar.h < m_ep[i].zone_bottom - e);
         if(fully_left)
           {
            int wi = WatchIndex(z.id, (ENUM_SCP_TF)tf_index);
            if(wi >= 0) m_w[wi].left_at = bar.close_time;
           }
         if(now > m_ep[i].deadline &&
            (m_ep[i].state == SCP_EP_WAIT_REACTION || m_ep[i].state == SCP_EP_TOUCHED))
            m_ep[i].state = SCP_EP_EXPIRED;
         if(now > m_ep[i].touch_at + 8 * PeriodSeconds(SCP_TF_PERIODS[tf_index]))
            m_ep[i].state = SCP_EP_EXPIRED;
        }
      for(int j = 0; j < m_break_count; j++)
         if(m_br[j].break_tf == (ENUM_SCP_TF)tf_index &&
            now > m_br[j].known_at + 7 * PeriodSeconds(SCP_TF_PERIODS[tf_index]))
            m_br[j].failed = true;
     }

   // Sự kiện phá: dùng cho S05/S06/S07.
   long              Record(long zone_id, ENUM_SCP_TF tf, int dir, datetime bar_time, datetime known_at,
                            double edge, bool is_p4, double invalidation, double bar_low, double bar_high, double bar_close)
     {
      if(m_break_count >= SCP_MAX_BREAKS)
        {
         for(int i = 0; i < m_break_count; i++)
           {
            if(m_br[i].consumed || m_br[i].failed)
              {
               ZeroMemory(m_br[i]);
               m_br[i].confirmed = true;
               m_br[i].id = m_next_break++;
               m_br[i].zone_id = zone_id;
               m_br[i].break_tf = tf;
               m_br[i].direction = dir;
               m_br[i].bar_time = bar_time;
               m_br[i].known_at = known_at;
               m_br[i].edge_bid = edge;
               m_br[i].is_p4 = is_p4;
               m_br[i].invalidation = invalidation;
               m_br[i].failed = false;
               m_br[i].consumed = false;
               m_br[i].bar_low = bar_low;
               m_br[i].bar_high = bar_high;
               m_br[i].bar_close = bar_close;
               return m_br[i].id;
              }
           }
         return 0;
        }
      ScpBreakEvent b;
      ZeroMemory(b);
      b.confirmed = true;
      b.id = m_next_break++;
      b.zone_id = zone_id;
      b.break_tf = tf;
      b.direction = dir;
      b.bar_time = bar_time;
      b.known_at = known_at;
      b.edge_bid = edge;
      b.is_p4 = is_p4;
      b.invalidation = invalidation;
      b.failed = false;
      b.consumed = false;
      b.bar_low = bar_low;
      b.bar_high = bar_high;
      b.bar_close = bar_close;
      m_br[m_break_count++] = b;
      return b.id;
     }

   void              ConsumeBreak(long break_id, int scenario = 0, datetime reaction_at = 0)
     {
      for(int i = 0; i < m_break_count; i++)
         if(m_br[i].id == break_id)
           {
            if(scenario > 0 && scenario <= 8) m_br[i].used_at[scenario] = reaction_at;
            else m_br[i].consumed = true;
            return;
           }
     }

   void              SetRole(long zone_id, ENUM_SCP_TF tf, int dir)
     {
      int wi=WatchIndex(zone_id,tf);
      if(wi>=0) m_w[wi].role=dir>0 ? SCP_ROLE_SUPPORT : SCP_ROLE_RESISTANCE;
     }

   int               BreakCount() { return m_break_count; }
   ScpBreakEvent     BreakAt(int i) { return m_br[i]; }

   // Một sự kiện xác nhận chỉ được dùng một lần (SPEC 6.3).
   void              ConsumeReaction(int index, datetime known_at, ENUM_SCP_REACTION kind)
     {
      if(index < 0 || index >= m_count)
         return;
      m_ep[index].reaction_at = known_at;
      m_ep[index].last_reaction = kind;
      m_ep[index].state = SCP_EP_REACTION_READY;
      m_ep[index].last_event_at = known_at;
     }

   // Phản ứng đã xét nhưng không thành kế hoạch: không dùng lại nến này, episode vẫn chờ phản ứng mới.
   void              SeenReaction(int index, datetime known_at)
     {
      if(index < 0 || index >= m_count)
         return;
      m_ep[index].reaction_at = known_at;
      m_ep[index].last_event_at = known_at;
     }

   void              Cleanup(datetime now, int max_age_sec)
     {
      for(int i = 0; i < m_count; i++)
        {
         if(m_ep[i].state == SCP_EP_EXPIRED || m_ep[i].state == SCP_EP_CANCELLED)
            continue;
         if(m_ep[i].last_event_at > 0 && (long)now - (long)m_ep[i].last_event_at > max_age_sec)
            m_ep[i].state = SCP_EP_EXPIRED;
        }
     }

   void              PruneWatches(ScpZoneMap &zones)
     {
      for(int i=m_wcount-1;i>=0;i--)
        {
         ScpZone z;
         if(zones.Find(m_w[i].zone_id,z) && z.alive) continue;
         for(int e=0;e<m_count;e++)
            if(m_ep[e].zone_id==m_w[i].zone_id) m_ep[e].state=SCP_EP_EXPIRED;
         m_w[i]=m_w[--m_wcount];
         if(i<m_wcount && m_w[i].zone_id>0) m_wmap[WKey(m_w[i].zone_id,m_w[i].tf)]=i;
        }
     }
  };

#endif // SCP_EPISODES_MQH
