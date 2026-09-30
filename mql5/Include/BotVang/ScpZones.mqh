// ScpZones.mqh — sổ vùng giá của bot SCP-MTF-1.3.
// Nguồn luật: docs/SPEC.md mục 5, 6.1, 14.3.
// Chỉ nhận nến đã đóng; không đọc MT5, không gửi lệnh.
#ifndef SCP_ZONES_MQH
#define SCP_ZONES_MQH

#include "ScpTypes.mqh"
#include "ScpSeries.mqh"
#include "ScpReaction.mqh"

#define SCP_MAX_ZONES     2048
#define SCP_ZONE_MAX_AGE  200   // tuổi tĩnh tối đa theo nến nguồn (SPEC mục 13)
#define SCP_OB_LOOKBACK   20    // số nến tìm OB (SPEC mục 13)
#define SCP_ZONE_MAP      65536 // bảng tra mã vùng -> ô; chỉ tăng tốc, luôn kiểm lại id

class ScpZoneMap
  {
private:
   ScpZone           m_z[SCP_MAX_ZONES];
   int               m_count;
   long              m_next_id;
   int               m_dropped;          // vùng mới bị bỏ vì bảng đầy (phải báo, không im lặng)
   bool              m_m1_target_needs_reaction;
   long              m_map_id[SCP_ZONE_MAP];
   int               m_map_slot[SCP_ZONE_MAP];

   void              MapPut(long id, int slot)
     {
      int k = (int)(id % SCP_ZONE_MAP);
      m_map_id[k] = id;
      m_map_slot[k] = slot;
     }

   // Ô của vùng theo mã; -1 nếu không có. Kết quả giống dò tuần tự vì luôn kiểm lại id.
   int               SlotOf(long id)
     {
      if(id <= 0) return -1;
      int k = (int)(id % SCP_ZONE_MAP);
      if(m_map_id[k] == id)
        {
         int s = m_map_slot[k];
         if(s >= 0 && s < m_count && m_z[s].id == id) return s;
        }
      for(int i = 0; i < m_count; i++)
         if(m_z[i].id == id) { MapPut(id, i); return i; }
      return -1;
     }

   // Vùng M1 chỉ làm cản mục tiêu khi đã có phản ứng được ghi nhận; tránh đỉnh/đáy M1 li ti chặn mọi lệnh.
   bool              TargetEligible(const ScpZone &z)
     {
      if(z.level == SCP_LEVEL_REFERENCE) return false;
      if(m_m1_target_needs_reaction && z.source_tf == SCP_TF_M1 && z.reaction_count < 1) return false;
      return true;
     }

   bool              Insert(const ScpZone &z)
     {
      if(m_count >= SCP_MAX_ZONES)
        {
         // Tái dùng ô đã chết để vùng mới vẫn vào được.
         for(int i = 0; i < m_count; i++)
           {
            if(!m_z[i].alive)
              {
               m_z[i] = z;
               MapPut(z.id, i);
               return true;
              }
           }
         m_dropped++;
         return false;
        }
      m_z[m_count++] = z;
      MapPut(z.id, m_count - 1);
      return true;
     }

   long              MergeOrInsert(const ScpZone &z)
     {
      // Chỉ chống trùng cùng nguồn. Không đổi biên/vai trò của một vùng đã được quan sát.
      for(int i = 0; i < m_count; i++)
         if(m_z[i].type == z.type && m_z[i].source_tf == z.source_tf &&
            m_z[i].source_role == z.source_role && m_z[i].origin_time == z.origin_time)
            return m_z[i].id;
      return Insert(z) ? z.id : 0;
     }

public:
                     ScpZoneMap() { m_dropped = 0; m_m1_target_needs_reaction = false; Init(); }
   int               Dropped() { return m_dropped; }
   void              SetM1TargetNeedsReaction(bool on) { m_m1_target_needs_reaction = on; }

   int               Count() { return m_count; }
   ScpZone           At(int i) { return m_z[i]; }

   bool              Find(long id, ScpZone &out)
     {
      int s = SlotOf(id);
      if(s < 0) return false;
      out = m_z[s];
      return true;
     }

   void              Init() { m_count = 0; m_next_id = 1; ArrayInitialize(m_map_id, 0); ArrayInitialize(m_map_slot, -1); }

   // Tạo vùng từ một pivot đã xác nhận. Vùng kháng cự [max(O,C), H], hỗ trợ [L, min(O,C)].
   long              AddFromPivot(ENUM_SCP_TF tf, const ScpBar &bar, bool is_high,
                                  datetime known_at, double atr_tf, double tick)
     {
      ScpZone z;
      z.id = m_next_id++;
      z.version = 1;
      z.type = SCP_ZONE_PIVOT;
      z.level = SCP_LEVEL_STRUCTURE;
      z.source_tf = tf;
      if(is_high)
        {
         z.bottom = MathMax(bar.o, bar.c);
         z.top = bar.h;
         z.source_role = SCP_ROLE_RESISTANCE;
        }
      else
        {
         z.bottom = bar.l;
         z.top = MathMin(bar.o, bar.c);
         z.source_role = SCP_ROLE_SUPPORT;
        }
      if(z.top < z.bottom)
         z.top = z.bottom;
      z.is_point = (MathAbs(z.top - z.bottom) < MathMax(tick, 1e-9));
      z.origin_time = bar.open_time;
      z.known_at = known_at;
      z.independent_touches = 0;
      z.reaction_count = 0;
      z.last_touch = 0;
      z.expires_at = 0;
      z.broken_up = false;
      z.broken_down = false;
      z.broken_up_at = 0;
      z.broken_down_at = 0;
      z.evidence_id = 0;
      z.alive = true;
      return MergeOrInsert(z);
     }

   // FVG tăng: L_c > H_a, vùng [H_a, L_c]; giảm đối xứng. Bề rộng đạt ngưỡng.
   long              AddFvg(ENUM_SCP_TF tf, int dir, double bottom, double top,
                            datetime origin, datetime known_at, double atr_tf, double tick,
                            bool structure_confirmed)
     {
      double min_width = MathMax(2.0 * tick, SCP_K_BUFFER * atr_tf);
      if((top - bottom) < min_width)
         return 0;
      ScpZone z;
      z.id = m_next_id++;
      z.version = 1;
      z.type = SCP_ZONE_FVG;
      z.level = structure_confirmed ? SCP_LEVEL_STRUCTURE : SCP_LEVEL_REFERENCE;
      z.source_tf = tf;
      z.bottom = bottom;
      z.top = top;
      z.source_role = (dir > 0) ? SCP_ROLE_SUPPORT : SCP_ROLE_RESISTANCE;
      z.is_point = false;
      z.origin_time = origin;
      z.known_at = known_at;
      z.independent_touches = 0;
      z.reaction_count = 0;
      z.last_touch = 0;
      z.expires_at = 0;
      z.broken_up = false;
      z.broken_down = false;
      z.broken_up_at = 0;
      z.broken_down_at = 0;
      z.evidence_id = 0;
      z.alive = true;
      return MergeOrInsert(z);
     }

   // OB: nến ngược chiều cuối trong chân đẩy dẫn tới đóng phá cấu trúc; vùng [L,H].
   long              AddOb(ENUM_SCP_TF tf, const ScpBar &bar, int dir,
                           datetime known_at, double tick)
     {
      ScpZone z;
      z.id = m_next_id++;
      z.version = 1;
      z.type = SCP_ZONE_OB;
      z.level = SCP_LEVEL_STRUCTURE;
      z.source_tf = tf;
      z.bottom = bar.l;
      z.top = bar.h;
      z.source_role = (dir > 0) ? SCP_ROLE_SUPPORT : SCP_ROLE_RESISTANCE;
      z.is_point = (MathAbs(z.top - z.bottom) < MathMax(tick, 1e-9));
      z.origin_time = bar.open_time;
      z.known_at = known_at;
      z.independent_touches = 0;
      z.reaction_count = 0;
      z.last_touch = 0;
      z.expires_at = 0;
      z.broken_up = false;
      z.broken_down = false;
      z.broken_up_at = 0;
      z.broken_down_at = 0;
      z.evidence_id = 0;
      z.alive = true;
      return MergeOrInsert(z);
     }

   // MSNR: cặp nến đổi màu; mức ở giá đóng của nến đầu.
   long              AddMsnr(ENUM_SCP_TF tf, double level, ENUM_SCP_ROLE role,
                             datetime origin, datetime known_at)
     {
      ScpZone z;
      z.id = m_next_id++;
      z.version = 1;
      z.type = SCP_ZONE_MSNR;
      z.level = SCP_LEVEL_REFERENCE;
      z.source_tf = tf;
      z.bottom = level;
      z.top = level;
      z.source_role = role;
      z.is_point = true;
      z.origin_time = origin;
      z.known_at = known_at;
      z.independent_touches = 0;
      z.reaction_count = 0;
      z.last_touch = 0;
      z.expires_at = 0;
      z.broken_up = false;
      z.broken_down = false;
      z.broken_up_at = 0;
      z.broken_down_at = 0;
      z.evidence_id = 0;
      z.alive = true;
      return MergeOrInsert(z);
     }

   // Một lần chạm độc lập: hai lần chạm trở lên nâng REFERENCE_ONLY thành REACTION_ONLY.
   void              RegisterTouch(long id, datetime t)
     {
      int i = SlotOf(id);
      if(i >= 0)
           {
            m_z[i].independent_touches++;
            m_z[i].last_touch = t;

            return;
           }
     }

   void              RegisterReaction(long id, long episode_id)
     {
      int i = SlotOf(id);
      if(i >= 0)
           {
            if(m_z[i].evidence_id == episode_id) return;
            m_z[i].evidence_id = episode_id;
            // last_touch chỉ là thời điểm, số phản ứng dùng trường riêng.
            m_z[i].reaction_count++;
            if(m_z[i].reaction_count >= 2 && m_z[i].level == SCP_LEVEL_REFERENCE)
               m_z[i].level = SCP_LEVEL_REACTION;
            return;
           }
     }

   void              MarkBroken(long id, int dir, datetime t)
     {
      int i = SlotOf(id);
      if(i >= 0)
           {
            if(dir > 0)
              {
               m_z[i].broken_up = true;
               m_z[i].broken_up_at = t;
              }
            else
              {
               m_z[i].broken_down = true;
               m_z[i].broken_down_at = t;
              }
            return;
           }
     }

   void              OnSourceBar(ENUM_SCP_TF tf, const ScpBar &bar, const ScpBar &prev, double atr, double eps)
     {
      for(int i=0;i<m_count;i++)
        {
         if(!m_z[i].alive || m_z[i].source_tf!=tf || bar.open_time<m_z[i].known_at) continue;
         int sec=PeriodSeconds(SCP_TF_PERIODS[tf]);
         if(m_z[i].broken_up && bar.open_time>=m_z[i].broken_up_at &&
            bar.open_time<=m_z[i].broken_up_at+5*sec &&
            ScpP5(prev,bar,1,m_z[i].top,bar.l<=m_z[i].top+eps && bar.h>=m_z[i].top-eps,atr,eps,0))
           { SetHeldRole(m_z[i].id,tf,1); continue; }
         if(m_z[i].broken_down && bar.open_time>=m_z[i].broken_down_at &&
            bar.open_time<=m_z[i].broken_down_at+5*sec &&
            ScpP5(prev,bar,-1,m_z[i].bottom,bar.h>=m_z[i].bottom-eps && bar.l<=m_z[i].bottom+eps,atr,eps,0))
           { SetHeldRole(m_z[i].id,tf,-1); continue; }
         if(!m_z[i].broken_up && m_z[i].source_role==SCP_ROLE_RESISTANCE && bar.c>m_z[i].top+eps)
            MarkBroken(m_z[i].id,1,bar.known_at);
         if(!m_z[i].broken_down && m_z[i].source_role==SCP_ROLE_SUPPORT && bar.c<m_z[i].bottom-eps)
            MarkBroken(m_z[i].id,-1,bar.known_at);
        }
     }

   void              SetHeldRole(long id, ENUM_SCP_TF tf, int dir)
     {
      int i=SlotOf(id);
      if(i>=0 && m_z[i].source_tf==tf)
           {
            m_z[i].source_role=dir>0 ? SCP_ROLE_SUPPORT : SCP_ROLE_RESISTANCE;
            m_z[i].broken_up=false; m_z[i].broken_down=false; m_z[i].version++;
           }
     }

   // Mép cản đối diện gần nhất còn hiệu lực theo hướng giao dịch.
   // dir=+1 (mua): tìm mép dưới (bottom) lớn hơn giá; dir=-1: mép trên (top) nhỏ hơn giá.
   bool              NearestOpposite(double bid, int dir, long skip_id, long &out_id, double &out_edge,
                                     ENUM_SCP_ROLE &out_role, ENUM_SCP_TF &out_tf, double buffer_eps,
                                     ENUM_SCP_TF max_tf=SCP_TF_D1,datetime known_before=0)
     {
      bool found = false;
      double best = 0.0;
      for(int i = 0; i < m_count; i++)
        {
         if(!m_z[i].alive || m_z[i].id == skip_id)
            continue;
         if(m_z[i].source_tf>max_tf) continue;
         if(known_before>0 && m_z[i].known_at>known_before) continue;
         if(!TargetEligible(m_z[i]))
            continue;   // mức tham khảo yếu/vùng M1 chưa có phản ứng không tự làm cản cứng
         double edge = (dir > 0) ? m_z[i].bottom : m_z[i].top;
         if(dir > 0)
           {
            if(m_z[i].source_role != SCP_ROLE_RESISTANCE || m_z[i].broken_up)
               continue;
            if(!(edge > bid + buffer_eps))
               continue;
            if(!found || edge < best)
              {
               best = edge;
               out_id = m_z[i].id;
               out_role = m_z[i].source_role;
               out_tf = m_z[i].source_tf;
               found = true;
              }
           }
         else
           {
            if(m_z[i].source_role != SCP_ROLE_SUPPORT || m_z[i].broken_down)
               continue;
            if(!(edge < bid - buffer_eps))
               continue;
            if(!found || edge > best)
              {
               best = edge;
               out_id = m_z[i].id;
               out_role = m_z[i].source_role;
               out_tf = m_z[i].source_tf;
               found = true;
              }
           }
        }
      if(found)
         out_edge = best;
      return found;
     }

   // Cần đích của nhịp M1/M5; cản khung lớn gần hơn vẫn được ưu tiên.
   bool NearestScalpTarget(double bid,int dir,long skip_id,long &id,double &edge,
                          ENUM_SCP_ROLE &role,ENUM_SCP_TF &tf)
     {
      for(int i=0;i<m_count;i++)
         if(m_z[i].alive && m_z[i].id!=skip_id && m_z[i].source_tf<=SCP_TF_M5 &&
            TargetEligible(m_z[i]) && (int)m_z[i].source_role==-dir &&
            !(dir>0 ? m_z[i].broken_up : m_z[i].broken_down) && ScpBetween(bid,m_z[i].bottom,m_z[i].top))
            return false;
      long local_id; double local_edge; ENUM_SCP_ROLE local_role; ENUM_SCP_TF local_tf;
      if(!NearestOpposite(bid,dir,skip_id,local_id,local_edge,local_role,local_tf,0,SCP_TF_M5)) return false;
      // Đệm/chi phí kiểm sau. Không bỏ qua một cản gần vì nó làm tỷ lệ lời/lỗ xấu.
      return NearestOpposite(bid,dir,skip_id,id,edge,role,tf,0);
     }

   // Hết tuổi theo tuổi tĩnh của vùng so với chuỗi nến nguồn (SPEC mục 13).
   void              ExpireByAge(ScpFrames &fr)
     {
      for(int i = 0; i < m_count; i++)
        {
         if(!m_z[i].alive)
            continue;
         ScpSeries *s = fr.Get(m_z[i].source_tf);
         if(s == NULL)
            continue;
         int n = s.Count();
         int age = 0;
         for(int b = n - 1; b >= 0; b--)
           {
            if(s.Bar(b).open_time <= m_z[i].origin_time)
               break;
            age++;
           }
         if(age > SCP_ZONE_MAX_AGE)
            m_z[i].alive = false;
        }
     }

  };

#endif // SCP_ZONES_MQH
