// SigLevels.mqh — sổ cản khung lớn cho công cụ đo tín hiệu (SPEC mục 22.2, 22.4).
// Nhận nến đã đóng do bên gọi đưa vào; không đọc MT5, không gửi lệnh.
#ifndef SIG_LEVELS_MQH
#define SIG_LEVELS_MQH

#include "ScpTypes.mqh"
#include "ScpSeries.mqh"

#define SIG_TF_COUNT    8
#define SIG_MAX_LEVELS  16384
#define SIG_LEVEL_AGE   200   // tuổi tối đa theo nến khung nguồn (SPEC 13)
#define SIG_OB_LOOKBACK 20
#define SIG_DOJI_BODY_ATR 0.3 // doji/thân nhỏ: thân <= 0,3 ATR và <= 50% biên độ (SPEC 22.4, THỬ NGHIỆM)
#define SIG_MOMO_BODY_ATR 0.6 // nến động lực: thân >= 0,6 ATR cùng chiều (SPEC 22.4, THỬ NGHIỆM)
#define SIG_MIN_TARGET_R 1.0 // đích cản khung lớn và DOL phải cách giá vào ít nhất 1R sau đệm (SPEC 23.4)

enum ENUM_SIG_TF { SIG_M1=0, SIG_M5=1, SIG_M15=2, SIG_M30=3, SIG_H1=4, SIG_H4=5, SIG_D1=6, SIG_W1=7 };
const ENUM_TIMEFRAMES SIG_PERIODS[SIG_TF_COUNT] =
  {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_W1};
// Số nến xác nhận pivot theo SPEC 13: M30 như M15/H1 (3), W1 như H4/D1 (2).
const ENUM_SCP_TF SIG_PIVOT_AS[SIG_TF_COUNT] =
  {SCP_TF_M1, SCP_TF_M5, SCP_TF_M15, SCP_TF_M15, SCP_TF_H1, SCP_TF_H4, SCP_TF_D1, SCP_TF_D1};

enum ENUM_SIG_LV { SIG_LV_PIVOT=0, SIG_LV_OB=1, SIG_LV_FVG=2, SIG_LV_PD=3, SIG_LV_PW=4, SIG_LV_ROUND=5, SIG_LV_DOJI=6,
                   SIG_LV_CLASSIC=7, SIG_LV_GAP=8 };

// Mã nhóm cản dùng trong báo cáo: 0 M5 tạm, 1..6 M15..W1, 7 ngày trước, 8 tuần trước, 9..11 số tròn.
#define SIG_G_M5TAM 0
#define SIG_G_PD    7
#define SIG_G_PW    8
#define SIG_G_R10   9
#define SIG_G_R50   10
#define SIG_G_R100  11
#define SIG_G_COUNT 12

// Phần trăm vốn chịu lỗ theo bậc cản (SPEC 22.1 mục 6, THỬ NGHIỆM).
const double SIG_TIER_RISK[5] = {0.10, 0.10, 0.15, 0.20, 0.25};

string SigGroupName(int g)
  {
   switch(g)
     {
      case SIG_G_M5TAM: return "M5_tam";
      case 1: return "M15";
      case 2: return "M30";
      case 3: return "H1";
      case 4: return "H4";
      case 5: return "D1";
      case 6: return "W1";
      case SIG_G_PD: return "ngay_truoc";
      case SIG_G_PW: return "tuan_truoc";
      case SIG_G_R10: return "so_tron_10";
      case SIG_G_R50: return "so_tron_50";
      case SIG_G_R100: return "so_tron_100";
     }
   return "?";
  }

string SigTypeName(int t)
  {
   switch(t)
     {
      case SIG_LV_PIVOT: return "dinh_day";
      case SIG_LV_OB: return "OB";
      case SIG_LV_FVG: return "FVG";
      case SIG_LV_PD: return "ngay_truoc";
      case SIG_LV_PW: return "tuan_truoc";
      case SIG_LV_ROUND: return "so_tron";
      case SIG_LV_DOJI: return "doji_snr";
      case SIG_LV_CLASSIC: return "classic_AV";
      case SIG_LV_GAP: return "gap_snr";
     }
   return "-";
  }

string SigDeadName(int why)
  {
   switch(why)
     {
      case 0: return "con";
      case 1: return "bi_pha";
      case 2: return "het_tuoi";
      case 3: return "het_ky";
      case 4: return "ky_moi";
     }
   return "-";
  }

struct SigLevel
  {
   long              id;
   int               tf;          // khung nguồn ENUM_SIG_TF; -1 với số tròn
   int               type;        // ENUM_SIG_LV
   int               group;       // mã nhóm báo cáo
   int               tier;        // bậc 0..4 trước khi xét trùng cản
   double            bottom, top;
   int               role;        // +1 hỗ trợ (tiếp cận từ trên), -1 kháng cự (từ dưới), 0 cả hai phía
   bool              wick;        // cản có râu: đo mốc thân, giữa râu, đỉnh/đáy râu (SPEC 22.4)
   double            lvl;         // đường mức thân (Classic/Gap: C(c1)); 0 = không có, chạm ở mép gần
   int               flip;        // 0 cản gốc; >=1 cản đã đổi vai sau khi bị phá (K2, SPEC 23.3)
   int               flip_def;    // cách phá tạo ra bản đổi vai: 1 thân đóng qua, 2 râu vượt, 3 cả hai
   bool              wick_broken; // râu đã vượt mép xa (định nghĩa phá b) nhưng thân chưa đóng qua
   bool              cont;        // đổi vai theo chiều K2 trước đó: tiếp diễn K5
   int               side0;       // phía giá lúc tạo (+1 trên, -1 dưới); dùng hết hiệu lực khi role = 0
   datetime          origin;      // giờ mở nến gốc
   datetime          known_at;
   datetime          valid_until; // 0: không hạn theo lịch
   datetime          dead_at;
   int               dead_why;    // 0 còn, 1 bị phá, 2 hết tuổi, 3 hết kỳ, 4 thay bằng kỳ mới
   int               age_start;   // số nến khung nguồn lúc tạo
   bool              alive;
   bool              fake;
   bool              swept;       // giá đã đi vượt đỉnh/đáy râu (dùng cho DOL)
   long              parent;
   int               arm_side[2][3]; // phía đã rời dải hoàn toàn theo [khung vào M1/M5][kiểu mốc]; 0 chưa rõ
   bool              ep_open[2][3];
   int               tests;       // số lần kiểm tra đã mở
   int               cur_test;    // số thứ tự lần kiểm tra đang mở (0 = lần đầu)
  };

class SigLevelBook
  {
private:
   SigLevel          m_lv[];
   int               m_n;
   long              m_next;
   ulong             m_seed;
   bool              m_fakes;
   double            m_tick;
   int               m_created[SIG_G_COUNT];
   int               m_fake_created, m_broken, m_aged, m_dropped;
   long              m_round_keys[];
   int               m_round_n;
   int               m_log;       // file ghi sổ cản; INVALID_HANDLE thì không ghi
   int               m_trend;     // chiều của tín hiệu K2 thật gần nhất (+1/-1), 0 chưa có

   void              Log(const SigLevel &z)
     {
      if(m_log==INVALID_HANDLE) return;
      FileWriteString(m_log,IntegerToString(z.id)+";"+(z.fake?"gia":"that")+";"+IntegerToString(z.parent)+";"+
                      SigGroupName(z.group)+";"+SigTypeName(z.type)+";"+(z.role>0?"ho_tro":(z.role<0?"khang_cu":"hai_phia"))+";"+
                      DoubleToString(z.bottom,3)+";"+DoubleToString(z.top,3)+";"+
                      TimeToString(z.origin,TIME_DATE|TIME_MINUTES)+";"+TimeToString(z.known_at,TIME_DATE|TIME_MINUTES)+";"+
                      (z.dead_at>0?TimeToString(z.dead_at,TIME_DATE|TIME_MINUTES):"-")+";"+SigDeadName(z.dead_why)+";"+
                      IntegerToString(z.tests)+"\r\n");
     }

   void              Kill(int i, datetime when, int why)
     {
      if(!m_lv[i].alive) return;
      m_lv[i].alive=false; m_lv[i].dead_at=when; m_lv[i].dead_why=why;
      if(why==1) m_broken++;
      if(why==2) m_aged++;
      Log(m_lv[i]);
     }

   int               Push(const SigLevel &z)
     {
      if(m_n>=SIG_MAX_LEVELS)
        {
         Compact();
         if(m_n>=SIG_MAX_LEVELS) { m_dropped++; return -1; }
        }
      if(m_n>=ArraySize(m_lv)) ArrayResize(m_lv,m_n+1024);
      m_lv[m_n++]=z;
      return m_n-1;
     }

   int               GroupOf(int tf, int type, int round_step)
     {
      if(type==SIG_LV_ROUND) return round_step>=100 ? SIG_G_R100 : (round_step>=50 ? SIG_G_R50 : SIG_G_R10);
      if(type==SIG_LV_PD) return SIG_G_PD;
      if(type==SIG_LV_PW) return SIG_G_PW;
      if(tf==SIG_M5) return SIG_G_M5TAM;
      return tf-1; // M15=1, M30=2, H1=3, H4=4, D1=5, W1=6
     }

   int               TierOf(int group)
     {
      switch(group)
        {
         case SIG_G_M5TAM: return 0;
         case 1: case 2: case SIG_G_R10: return 1;        // M15, M30, số tròn $10
         case 3: case SIG_G_R50: case SIG_G_PD: return 2;  // H1, $50, đỉnh/đáy ngày trước
         case 4: case SIG_G_R100: case SIG_G_PW: return 3; // H4, $100, đỉnh/đáy tuần trước
        }
      return 4; // D1, W1
     }

   // Cản giả cùng khung/loại/bề rộng/vai trò, lệch ngẫu nhiên 1–3 lần max(bề rộng, ATR nguồn); đi qua cùng quy trình.
   void              AddFake(const SigLevel &real, double src_atr, double price_now)
     {
      if(!m_fakes) return;
      double w=real.top-real.bottom;
      double unit=MathMax(w,src_atr);
      if(real.type==SIG_LV_ROUND) unit=MathMax(unit,2.0);
      if(unit<=0) return;
      double off=(1.0+2.0*Rand01())*unit*(Rand01()<0.5 ? -1.0 : 1.0);
      SigLevel z=real;
      z.id=m_next++;
      z.bottom=ScpRoundNear(real.bottom+off,m_tick);
      z.top=z.bottom+w;
      if(real.lvl>0) z.lvl=real.lvl+(z.bottom-real.bottom);
      z.fake=true;
      z.parent=real.id;
      z.side0=(price_now>=(z.bottom+z.top)*0.5) ? 1 : -1;
      z.tests=0; z.cur_test=0; z.swept=false;
      ArrayInitialize(z.arm_side,0); ArrayInitialize(z.ep_open,false);
      if(Push(z)>=0) m_fake_created++;
     }

   long              Add(int tf, int type, double bottom, double top, int role, bool wick, datetime origin,
                         datetime known, datetime valid_until, double src_atr, int age_start, double price_now, int round_step,
                         double lvl=0)
     {
      if(top<bottom) { double t=top; top=bottom; bottom=t; }
      SigLevel z;
      ZeroMemory(z);
      z.id=m_next++;
      z.tf=tf; z.type=type;
      z.group=GroupOf(tf,type,round_step);
      z.tier=TierOf(z.group);
      z.bottom=bottom; z.top=top;
      z.role=role; z.wick=wick; z.lvl=lvl;
      z.side0=(price_now>=(bottom+top)*0.5) ? 1 : -1;
      z.origin=origin; z.known_at=known; z.valid_until=valid_until; z.age_start=age_start;
      z.alive=true; z.fake=false; z.parent=0; z.swept=false;
      if(Push(z)<0) return 0;
      m_created[z.group]++;
      AddFake(z,src_atr,price_now);
      return z.id;
     }

   // Doji SnR (SPEC 22.4): động lực c1 → 1–2 doji/thân nhỏ → động lực c3 cùng chiều đóng vượt cụm doji.
   void              DetectDoji(int tf, ScpSeries *s, double atr, double price_now)
     {
      int n=s.Count();
      if(n<5 || atr<=0) return;
      ScpBar c3=s.Bar(n-1);
      double b3=c3.c-c3.o;
      if(MathAbs(b3)<SIG_MOMO_BODY_ATR*atr) return;
      int dir=(b3>0) ? 1 : -1;
      for(int k=1;k<=2;k++)
        {
         // Cụm doji là các nến n-1-k .. n-2; nến động lực c1 ở n-2-k.
         double dhi=0, dlo=DBL_MAX;
         bool ok=true;
         for(int d=n-1-k;d<=n-2;d++)
           {
            ScpBar b=s.Bar(d);
            double body=MathAbs(b.c-b.o), range=b.h-b.l;
            if(body>SIG_DOJI_BODY_ATR*atr || (range>0 && body>0.5*range)) { ok=false; break; }
            dhi=MathMax(dhi,b.h); dlo=MathMin(dlo,b.l);
           }
         if(!ok) continue;
         ScpBar c1=s.Bar(n-2-k);
         if(dir*(c1.c-c1.o)<SIG_MOMO_BODY_ATR*atr) continue;
         // c3 đóng vượt qua cụm doji theo chiều đi.
         if((dir>0 && c3.c<=dhi) || (dir<0 && c3.c>=dlo)) continue;
         double level=c3.o;
         // Tăng: hỗ trợ [đáy râu cụm doji, mốc]; giảm: kháng cự [mốc, đỉnh râu cụm doji].
         double lo=(dir>0) ? MathMin(dlo,level) : level;
         double hi=(dir>0) ? level : MathMax(dhi,level);
         Add(tf,SIG_LV_DOJI,lo,hi,dir,true,c1.open_time,c3.known_at,0,atr,n,price_now,0);
         return;
        }
     }

   // Bản đổi vai của cản i sau khi bị phá (Rare SnR SBR/RBS): cùng hình học, vai ngược, mới ở phía kia.
   void              AddFlip(int i, datetime known, int def)
     {
      for(int j=0;j<m_n;j++)
         if(m_lv[j].parent==m_lv[i].id && m_lv[j].flip==m_lv[i].flip+1 && m_lv[j].fake==m_lv[i].fake && m_lv[j].alive)
           { m_lv[j].flip_def|=def; return; }
      SigLevel z=m_lv[i];
      z.id=m_next++;
      z.parent=m_lv[i].id;
      z.role=-m_lv[i].role;
      z.flip=m_lv[i].flip+1; z.flip_def=def; z.wick_broken=false;
      z.cont=(m_trend!=0 && m_trend==z.role);
      // Giữ tuổi (age_start) của cản gốc: bản đổi vai hết hạn cùng lúc với cản gốc.
      z.known_at=known; z.alive=true; z.dead_at=0; z.dead_why=0;
      z.tests=0; z.cur_test=0; z.swept=true;
      ArrayInitialize(z.arm_side,0); ArrayInitialize(z.ep_open,false);
      Push(z);
     }

public:
                     SigLevelBook() { m_log=INVALID_HANDLE; Init(0.01,1,true); }

   void              Init(double tick, ulong seed, bool fakes)
     {
      m_n=0; m_next=1; m_seed=seed; m_fakes=fakes; m_tick=(tick>0 ? tick : 0.01);
      ArrayInitialize(m_created,0);
      m_fake_created=0; m_broken=0; m_aged=0; m_dropped=0;
      m_round_n=0; m_trend=0;
      ArrayResize(m_lv,0,4096); ArrayResize(m_round_keys,0,256);
     }

   void              SetLog(int fh) { m_log=fh; }
   void              SetTrend(int dir) { m_trend=dir; }

   double            Rand01()
     {
      m_seed=m_seed*6364136223846793005+1442695040888963407;
      return (double)(m_seed>>11)/9007199254740992.0;
     }

   int               Count() { return m_n; }
   int               Created(int group) { return m_created[group]; }
   int               FakeCreated() { return m_fake_created; }
   int               Broken() { return m_broken; }
   int               Aged() { return m_aged; }
   int               Dropped() { return m_dropped; }

   bool              Get(int i, SigLevel &out) { if(i<0 || i>=m_n) return false; out=m_lv[i]; return true; }
   int               ArmSide(int i, int etf, int v) { return m_lv[i].arm_side[etf][v]; }
   void              SetArm(int i, int etf, int v, int side) { m_lv[i].arm_side[etf][v]=side; }
   bool              EpOpen(int i, int etf, int v) { return m_lv[i].ep_open[etf][v]; }
   void              SetEpOpen(int i, int etf, int v, bool on) { m_lv[i].ep_open[etf][v]=on; }
   bool              AnyOpen(int i)
     {
      for(int e=0;e<2;e++) for(int v=0;v<3;v++) if(m_lv[i].ep_open[e][v]) return true;
      return false;
     }
   int               IndexOf(long id)
     {
      for(int i=0;i<m_n;i++) if(m_lv[i].id==id) return i;
      return -1;
     }

   // Mở một lần kiểm tra. Các lần chạm (M1/M5, các kiểu mốc) còn mở cùng lúc dùng chung số thứ tự.
   int               BeginTest(int i)
     {
      if(AnyOpen(i)) return m_lv[i].cur_test;
      m_lv[i].cur_test=m_lv[i].tests;
      m_lv[i].tests++;
      return m_lv[i].cur_test;
     }

   // Giá đi vượt đỉnh/đáy râu: cản đã bị quét thanh khoản.
   void              MarkSweep(int i, double bid)
     {
      if(m_lv[i].swept) return;
      if((m_lv[i].role<0 && bid>m_lv[i].top) || (m_lv[i].role>0 && bid<m_lv[i].bottom)) m_lv[i].swept=true;
     }

   // Dọn cản đã chết (không còn lần chạm đang mở).
   void              Compact()
     {
      int w=0;
      for(int i=0;i<m_n;i++)
        {
         if(!m_lv[i].alive && !AnyOpen(i)) continue;
         if(w!=i) m_lv[w]=m_lv[i];
         w++;
        }
      m_n=w;
     }

   bool              Usable(int i, datetime now)
     {
      if(!m_lv[i].alive || m_lv[i].known_at>now) return false;
      if(m_lv[i].valid_until>0 && now>m_lv[i].valid_until) { Kill(i,now,3); return false; }
      return true;
     }

   // Cản mới từ nến vừa đóng của khung nguồn: đỉnh/đáy (vùng râu), Doji SnR, FVG, OB (hình học SPEC 14.3, 22.4).
   void              OnSourceBar(int tf, ScpSeries *s, long &seen_pivot, double price_now)
     {
      if(s==NULL || s.Count()<4) return;
      int n=s.Count();
      double atr=s.Atr();
      ScpBar last=s.Bar(n-1);
      for(int i=0;i<s.PivotCount();i++)
        {
         ScpPivot p=s.Pivot(i);
         if(p.id<=seen_pivot) continue;
         seen_pivot=p.id;
         if(p.ambiguous) continue;
         for(int b=n-1;b>=MathMax(0,n-1-SIG_LEVEL_AGE);b--)
           {
            ScpBar src=s.Bar(b);
            if(src.open_time!=p.bar_time) continue;
            // Kháng cự [mép thân trên, đỉnh râu]; hỗ trợ [đáy râu, mép thân dưới].
            double lo=p.is_high ? MathMax(src.o,src.c) : src.l;
            double hi=p.is_high ? src.h : MathMin(src.o,src.c);
            Add(tf,SIG_LV_PIVOT,lo,hi,p.is_high ? -1 : 1,true,src.open_time,p.known_at,0,atr,n,price_now,0);
            // Classic A (đỉnh) / V (đáy) có nến pivot là c1 hoặc c2 (SPEC 23.2 L2; lọc đề xuất).
            if(tf!=SIG_M5)
               for(int c1i=b-1;c1i<=b;c1i++)
                 {
                  if(c1i<0 || c1i+1>=n) continue;
                  ScpBar c1=s.Bar(c1i), c2=s.Bar(c1i+1);
                  if(p.is_high && c1.c>c1.o && c2.c<c2.o)
                     Add(tf,SIG_LV_CLASSIC,c1.c,MathMax(c1.h,c2.h),-1,false,c1.open_time,p.known_at,0,atr,n,price_now,0,c1.c);
                  if(!p.is_high && c1.c<c1.o && c2.c>c2.o)
                     Add(tf,SIG_LV_CLASSIC,MathMin(c1.l,c2.l),c1.c,1,false,c1.open_time,p.known_at,0,atr,n,price_now,0,c1.c);
                 }
            break;
           }
        }
      if(tf==SIG_M5) return; // cản tạm M5 chỉ dùng vùng đỉnh/đáy
      DetectDoji(tf,s,atr,price_now);
      // Gap SnR: hai nến cùng màu, ít nhất một nến thân >= 0,6 ATR (lọc đề xuất); mức C(c1), vùng [LL, UL] (SPEC 23.2 L3).
      ScpBar g1=s.Bar(n-2), g2=s.Bar(n-1);
      bool strong=(MathAbs(g1.c-g1.o)>=SIG_MOMO_BODY_ATR*atr || MathAbs(g2.c-g2.o)>=SIG_MOMO_BODY_ATR*atr);
      if(strong && g1.c<g1.o && g2.c<g2.o)
         Add(tf,SIG_LV_GAP,g1.l,MathMax(g2.h,g1.c),-1,false,g1.open_time,g2.known_at,0,atr,n,price_now,0,g1.c);
      if(strong && g1.c>g1.o && g2.c>g2.o)
         Add(tf,SIG_LV_GAP,MathMin(g2.l,g1.c),g1.h,1,false,g1.open_time,g2.known_at,0,atr,n,price_now,0,g1.c);
      // FVG ba nến, nến giữa cùng chiều khoảng trống, bề rộng tối thiểu.
      ScpBar a=s.Bar(n-3), mid=s.Bar(n-2), c=s.Bar(n-1);
      double min_w=MathMax(2.0*m_tick,SCP_K_BUFFER*atr);
      if(c.l>a.h && mid.c>mid.o && c.l-a.h>=min_w) Add(tf,SIG_LV_FVG,a.h,c.l,1,false,a.open_time,c.known_at,0,atr,n,price_now,0);
      if(c.h<a.l && mid.c<mid.o && a.l-c.h>=min_w) Add(tf,SIG_LV_FVG,c.h,a.l,-1,false,a.open_time,c.known_at,0,atr,n,price_now,0);
      // OB: nến đóng phá đỉnh/đáy đã biết → nến ngược chiều cuối trong 20 nến trước; phá lên tạo OB hỗ trợ.
      double hi=s.LastPivotPrice(true), lo=s.LastPivotPrice(false);
      double eps=SCP_K_BUFFER*s.AtrAt(n-2);
      int dir=0;
      if(hi>0 && s.LastPivotKnownAt(true)<=last.open_time && mid.c<=hi+eps && last.c>hi+eps) dir=1;
      if(lo>0 && s.LastPivotKnownAt(false)<=last.open_time && mid.c>=lo-eps && last.c<lo-eps) dir=-1;
      if(dir!=0)
         for(int k=n-2;k>=MathMax(0,n-1-SIG_OB_LOOKBACK);k--)
           {
            ScpBar ob=s.Bar(k);
            if((dir>0 && ob.c<ob.o) || (dir<0 && ob.c>ob.o))
              { Add(tf,SIG_LV_OB,ob.l,ob.h,dir,false,ob.open_time,last.known_at,0,atr,n,price_now,0); break; }
           }
     }

   // Cản của khung nguồn hết hiệu lực: nến khung đó đóng vượt mép xa thêm eps, hoặc quá tuổi.
   void              ExpireBySource(int tf, ScpSeries *s)
     {
      if(s==NULL || s.Count()<1) return;
      ScpBar b=s.LastBar();
      double eps=SCP_K_BUFFER*s.Atr();
      int n=s.Count();
      for(int i=0;i<m_n;i++)
        {
         if(!m_lv[i].alive || m_lv[i].tf!=tf) continue;
         if(m_lv[i].type==SIG_LV_ROUND || m_lv[i].type==SIG_LV_PD || m_lv[i].type==SIG_LV_PW) continue;
         int side=(m_lv[i].role!=0) ? m_lv[i].role : m_lv[i].side0;
         // Chỉ cản gốc khung M15 trở lên được đổi vai, và chỉ một lần (SPEC 23.2); cản dao động qua lại không được làm mới mãi.
         bool flippable=(m_lv[i].flip==0 && m_lv[i].group!=SIG_G_M5TAM &&
                         (m_lv[i].type==SIG_LV_PIVOT || m_lv[i].type==SIG_LV_CLASSIC || m_lv[i].type==SIG_LV_GAP ||
                          m_lv[i].type==SIG_LV_DOJI));
         if((side>0 && b.c<m_lv[i].bottom-eps) || (side<0 && b.c>m_lv[i].top+eps))
           {
            if(flippable && m_lv[i].known_at<=b.open_time) AddFlip(i,b.known_at,1);
            Kill(i,b.close_time,1);
            continue;
           }
         if(flippable && !m_lv[i].wick_broken && m_lv[i].known_at<=b.open_time &&
            ((side>0 && b.l<m_lv[i].bottom-eps) || (side<0 && b.h>m_lv[i].top+eps)))
           {
            m_lv[i].wick_broken=true;
            AddFlip(i,b.known_at,2);
           }
         if(n-m_lv[i].age_start>SIG_LEVEL_AGE) Kill(i,b.close_time,2);
        }
     }

   // Đỉnh/đáy kỳ vừa hoàn thành (ngày hoặc tuần), dùng tới hết kỳ kế tiếp; tiếp cận được từ cả hai phía.
   void              AddPeriodExtremes(int type, const ScpBar &bar, double src_atr, double price_now)
     {
      datetime until=bar.close_time+(bar.close_time-bar.open_time);
      for(int i=0;i<m_n;i++)
         if(m_lv[i].alive && m_lv[i].type==type) Kill(i,bar.close_time,4);
      int tf=(type==SIG_LV_PD) ? SIG_D1 : SIG_W1;
      Add(tf,type,bar.h,bar.h,0,false,bar.open_time,bar.known_at,until,src_atr,0,price_now,0);
      Add(tf,type,bar.l,bar.l,0,false,bar.open_time,bar.known_at,until,src_atr,0,price_now,0);
     }

   // Số tròn $10/$50/$100 quanh giá; tạo dần khi giá đi tới.
   void              EnsureRound(double price, datetime now)
     {
      long base=(long)MathFloor(price/10.0);
      for(long k=base-5;k<=base+5;k++)
        {
         bool have=false;
         for(int j=0;j<m_round_n;j++) if(m_round_keys[j]==k) { have=true; break; }
         if(have) continue;
         if(m_round_n>=ArraySize(m_round_keys)) ArrayResize(m_round_keys,m_round_n+256);
         m_round_keys[m_round_n++]=k;
         double lvl=(double)k*10.0;
         int step=(k%10==0) ? 100 : ((k%5==0) ? 50 : 10);
         Add(-1,SIG_LV_ROUND,lvl,lvl,0,false,now,now,0,0,0,price,step);
        }
     }

   // Số cản khác nhóm/loại (bậc M15 trở lên, cùng lớp thật/giả) có dải chồng dải của cản i.
   int               Confluence(int i, double eps, datetime now)
     {
      int c=0;
      for(int j=0;j<m_n;j++)
        {
         if(j==i || m_lv[j].fake!=m_lv[i].fake || !m_lv[j].alive || m_lv[j].known_at>now) continue;
         if(m_lv[j].group==m_lv[i].group && m_lv[j].type==m_lv[i].type) continue;
         if(m_lv[j].tier<1) continue;
         if(m_lv[j].bottom-eps<=m_lv[i].top+eps && m_lv[j].top+eps>=m_lv[i].bottom-eps) c++;
        }
      return c;
     }

   // Mép gần của cản thật phía trước theo chiều lệnh. htf=true: bậc M15 trở lên; false: cản tạm M5.
   double            NearestAhead(int dir, double price, bool htf, datetime now)
     {
      double best=0;
      for(int i=0;i<m_n;i++)
        {
         if(m_lv[i].fake || !m_lv[i].alive || m_lv[i].known_at>now) continue;
         if(m_lv[i].valid_until>0 && now>m_lv[i].valid_until) continue;
         if(htf==(m_lv[i].group==SIG_G_M5TAM)) continue;
         if(dir>0 && m_lv[i].bottom>price && (best==0 || m_lv[i].bottom<best)) best=m_lv[i].bottom;
         if(dir<0 && m_lv[i].top<price && (best==0 || m_lv[i].top>best)) best=m_lv[i].top;
        }
      return best;
     }

   // Mép đích phải vượt mức này để cách giá vào ít nhất SIG_MIN_TARGET_R (đã trừ đệm; lệnh bán tính cả spread).
   // r: khoảng tới dừng; buf: đệm chốt trước mép.
   double            TargetFrom(int dir, double bid, double ask, double buf, double r)
     {
      return (dir>0) ? ask+buf+SIG_MIN_TARGET_R*r : bid-(ask-bid)-buf-SIG_MIN_TARGET_R*r;
     }

   // Đích cản khung lớn: mép gần của cản M15 trở lên đầu tiên đủ xa; cản gần hơn, kể cả cản chồng lên vùng vào lệnh, bỏ qua.
   double            HtfTarget(int dir, double bid, double ask, double buf, double r, datetime now)
     {
      return NearestAhead(dir,TargetFrom(dir,bid,ask,buf,r),true,now);
     }

   // Đích DOL: đỉnh/đáy râu chưa bị quét đầu tiên đủ xa; đỉnh/đáy gần hơn bỏ qua.
   double            DolTarget(int dir, double bid, double ask, double buf, double r, datetime now)
     {
      return NearestDol(dir,TargetFrom(dir,bid,ask,buf,r),now);
     }

   // DOL: đỉnh/đáy râu gần nhất phía trước của cản đỉnh/đáy M15 trở lên chưa bị quét (SPEC 22.4).
   double            NearestDol(int dir, double price, datetime now)
     {
      double best=0;
      for(int i=0;i<m_n;i++)
        {
         if(m_lv[i].fake || m_lv[i].type!=SIG_LV_PIVOT || m_lv[i].tf<SIG_M15 || m_lv[i].flip>0) continue;
         if(m_lv[i].swept || m_lv[i].known_at>now) continue;
         if(dir>0 && m_lv[i].role<0 && m_lv[i].top>price && (best==0 || m_lv[i].top<best)) best=m_lv[i].top;
         if(dir<0 && m_lv[i].role>0 && m_lv[i].bottom<price && (best==0 || m_lv[i].bottom>best)) best=m_lv[i].bottom;
        }
      return best;
     }

   // Chỉ số các cản còn dùng được có dải nằm trong bán kính quanh giá.
   int               Near(double price, double radius, datetime now, int &out[])
     {
      int k=0;
      ArrayResize(out,0,256);
      for(int i=0;i<m_n;i++)
        {
         if(!Usable(i,now)) continue;
         if(m_lv[i].bottom-radius>price || m_lv[i].top+radius<price) continue;
         ArrayResize(out,k+1,256);
         out[k++]=i;
        }
      return k;
     }

   // Ghi các cản còn sống lúc kết thúc lượt đo.
   void              FlushLog()
     {
      for(int i=0;i<m_n;i++) if(m_lv[i].alive) Log(m_lv[i]);
     }
  };

#endif // SIG_LEVELS_MQH
