// ScpReaction.mqh — các mẫu xác nhận P1..P5 theo SPEC mục 7 và 14.4.
// Hàm thuần trên nến đã đóng và tham số hình học; không đọc MT5, không gửi lệnh.
#ifndef SCP_REACTION_MQH
#define SCP_REACTION_MQH

#include "ScpTypes.mqh"

double ScpBody(const ScpBar &b) { return MathAbs(b.c - b.o); }
double ScpRange(const ScpBar &b) { return b.h - b.l; }
double ScpLowerWick(const ScpBar &b) { return MathMin(b.o, b.c) - b.l; }
double ScpUpperWick(const ScpBar &b) { return b.h - MathMax(b.o, b.c); }
double ScpLocationBuy(const ScpBar &b)
  {
   double r = ScpRange(b);
   return (r <= 0.0) ? 0.0 : (b.c - b.l) / r;
  }
double ScpLocationSell(const ScpBar &b)
  {
   double r = ScpRange(b);
   return (r <= 0.0) ? 0.0 : (b.h - b.c) / r;
  }

// B0: nến E đóng vượt mép vùng theo chiều phá thêm đệm.
bool ScpB0(const ScpBar &b, int dir, double edge, double eps)
  {
   if(dir > 0)
      return (b.c > edge + eps);
   return (b.c < edge - eps);
  }

// P4: đóng vượt mép + thân đủ mạnh + đóng gần đầu phía phá.
bool ScpP4(const ScpBar &b, int dir, double edge, double atr_ref, double eps)
  {
   if(ScpRange(b) <= 0.0)
      return false;
   if(!ScpB0(b, dir, edge, eps))
      return false;
   double body = ScpBody(b);
   if(body < 0.8 * atr_ref)
      return false;
   if(dir > 0)
      return (b.c > b.o && ScpLocationBuy(b) >= 0.75);
   return (b.c < b.o && ScpLocationSell(b) >= 0.75);
  }

// P1: râu từ chối tại lần chạm. `touched` do bên gọi xác nhận đã chạm vùng trong episode.
bool ScpP1(const ScpBar &b, int dir, double zone_bottom, double zone_top, double atr_ref, bool touched)
  {
   if(!touched)
      return false;
   double r = ScpRange(b);
   if(r <= 0.0)
      return false;
   double body = ScpBody(b);
   if(dir > 0)
     {
      double lw = ScpLowerWick(b);
      if(!(lw >= 2.0 * body) || !(lw >= 0.5 * atr_ref))
         return false;
      if(!(ScpLocationBuy(b) >= 2.0 / 3.0))
         return false;
      if(!(b.c > zone_top) || !(b.c >= b.o))
         return false;
      return true;
     }
   double uw = ScpUpperWick(b);
   if(!(uw >= 2.0 * body) || !(uw >= 0.5 * atr_ref))
      return false;
   if(!(ScpLocationSell(b) >= 2.0 / 3.0))
      return false;
   if(!(b.c < zone_bottom) || !(b.c <= b.o))
      return false;
   return true;
  }

// P2: nhấn chìm hai nến theo chiều phản ứng; một trong hai nến đã chạm vùng.
bool ScpP2(const ScpBar &prev, const ScpBar &cur, int dir, double zone_bottom, double zone_top, bool touched_in_pair)
  {
   if(!touched_in_pair)
      return false;
   double body_prev = ScpBody(prev);
   double body_cur = ScpBody(cur);
   if(!(body_cur > body_prev))
      return false;
   if(dir > 0)
     {
      if(!(prev.c < prev.o))
         return false;              // nến trước đỏ
      if(!(cur.c > cur.o))
         return false;              // nến hiện tại xanh
      if(!(cur.o <= prev.c) || !(cur.c >= prev.o))
         return false;              // thân bao phủ thân trước
      if(!(cur.c > zone_top))
         return false;
      return true;
     }
   if(!(prev.c > prev.o))
      return false;
   if(!(cur.c < cur.o))
      return false;
   if(!(cur.o >= prev.c) || !(cur.c <= prev.o))
      return false;
   if(!(cur.c < zone_bottom))
      return false;
   return true;
  }

// P3: nến đóng vượt đỉnh/đáy nhỏ đã khóa của nhịp đi vào vùng thêm đệm.
bool ScpP3(const ScpBar &b, int dir, double small_level, double eps, bool touched)
  {
   if(!touched || small_level <= 0.0)
      return false;
   if(dir > 0)
      return (b.c > small_level + eps);
   return (b.c < small_level - eps);
  }

// P5: kiểm tra lại giữ được phía mới quanh mép đã đổi vai trò.
// `retest_touched` là giá đã quay lại vùng kiểm tra [edge±eps] sau sự kiện phá.
bool ScpP5(const ScpBar &prev, const ScpBar &cur, int dir, double edge, bool retest_touched,
           double atr_ref, double eps, double small_level)
  {
   if(!retest_touched)
      return false;
   double zb = edge - eps;
   double zt = edge + eps;
   bool any = false;
   if(dir > 0)
     {
      // Giữ phía trên mép: các mẫu tăng quanh mép, không đóng lại dưới mép - đệm.
      any = ScpP1(cur, +1, zb, zt, atr_ref, true) ||
            ScpP2(prev, cur, +1, zb, zt, true) ||
            ScpP3(cur, +1, small_level, eps, true);
      if(cur.c < edge - eps)
         any = false;
     }
   else
     {
      any = ScpP1(cur, -1, zb, zt, atr_ref, true) ||
            ScpP2(prev, cur, -1, zb, zt, true) ||
            ScpP3(cur, -1, small_level, eps, true);
      if(cur.c > edge + eps)
         any = false;
     }
   return any;
  }

ENUM_SCP_REACTION ScpReactionAt(const ScpBar &prev,const ScpBar &cur,int dir,double lo,double hi,
                               double atr,double eps,double small,bool touched)
  {
   if(ScpP1(cur,dir,lo,hi,atr,touched)) return SCP_RE_P1;
   if(ScpP2(prev,cur,dir,lo,hi,touched)) return SCP_RE_P2;
   if(ScpP3(cur,dir,small,eps,touched)) return SCP_RE_P3;
   return SCP_RE_NONE;
  }

#endif // SCP_REACTION_MQH
