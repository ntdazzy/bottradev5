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
#define SIG_DISP_BARS   5     // lực bật: số nến khung nguồn sau nến gốc (SPEC 24.1, THỬ NGHIỆM)
#define SIG_BOS_BARS    20    // phá cấu trúc: theo dõi tối đa số nến sau nến gốc, dừng khi có lần chạm đầu (SPEC 24.1)
#define SIG_MOMO_FULL   0.6   // nến động lực: thân >= 60% biên độ (Rare SnR "thân dài"; ngưỡng ATR đo theo nhóm)
#define SIG_RANK_CAP    500   // độ lớn đỉnh/đáy: đếm tối đa số nến bên trái
#define SIG_UNI_AGE     24    // Unicorn: hạn tìm và hạn dùng, số nến khung nguồn (SPEC 23.3 K3, THỬ NGHIỆM)
#define SIG_UNI_EQ_ATR  0.1   // DOL đỉnh/đáy bằng nhau: chênh <= 0,1 ATR khung nguồn (SPEC 23.3 K3, THỬ NGHIỆM)
#define SIG_PENDING     D'3000.01.01' // vùng chưa đủ điều kiện dùng
// Tuổi tối đa theo thời gian (SPEC 24.5, chủ bot chọn 29/09, THỬ NGHIỆM): M15–H1 5 ngày, H4 3 tuần, D1 3 tháng, W1 1 năm.
const long SIG_AGE_SEC[8] = {0, 0, 5*86400, 5*86400, 5*86400, 21*86400, 90*86400, 365*86400};
// Tinh chỉnh vùng khung lớn xuống khung nhỏ (SPEC 24.5; Rare SnR tr.10, 411 tr.14): hai bước, -1 = không có.
const int  SIG_REFINE[8][2] = {{-1,-1},{-1,-1},{-1,-1},{-1,-1},{-1,-1},{4,2},{5,4},{6,5}};
const string SIG_TF_NAME[8] = {"M1","M5","M15","M30","H1","H4","D1","W1"};

enum ENUM_SIG_TF { SIG_M1=0, SIG_M5=1, SIG_M15=2, SIG_M30=3, SIG_H1=4, SIG_H4=5, SIG_D1=6, SIG_W1=7 };
const ENUM_TIMEFRAMES SIG_PERIODS[SIG_TF_COUNT] =
  {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_W1};
// Số nến xác nhận pivot theo SPEC 13: M30 như M15/H1 (3), W1 như H4/D1 (2).
const ENUM_SCP_TF SIG_PIVOT_AS[SIG_TF_COUNT] =
  {SCP_TF_M1, SCP_TF_M5, SCP_TF_M15, SCP_TF_M15, SCP_TF_H1, SCP_TF_H4, SCP_TF_D1, SCP_TF_D1};

enum ENUM_SIG_LV { SIG_LV_PIVOT=0, SIG_LV_OB=1, SIG_LV_FVG=2, SIG_LV_PD=3, SIG_LV_PW=4, SIG_LV_ROUND=5, SIG_LV_DOJI=6,
                   SIG_LV_CLASSIC=7, SIG_LV_GAP=8, SIG_LV_Z=9, SIG_LV_UNI=10 };

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
      case SIG_LV_Z: return "vung_Z_411";
      case SIG_LV_UNI: return "unicorn";
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
   // Sức mạnh cản (SPEC 24.1). Cản giả chép số của cản thật gốc. -1 = không áp dụng (số tròn, đỉnh/đáy kỳ).
   double            atr_src;     // ATR khung nguồn lúc tạo
   long              origin_no;   // số thứ tự nến gốc trong khung nguồn
   double            disp;        // lực bật: quãng giá rời mép gần trong SIG_DISP_BARS nến sau nến gốc (ATR nguồn)
   double            body_max;    // thân lớn nhất theo chiều rời cản từ nến gốc tới hết SIG_DISP_BARS (ATR nguồn; thân >= 60% biên độ)
   int               bos;         // số đỉnh/đáy đối diện (tối đa 2, gần nhất trước nến gốc) bị đóng vượt trước lần chạm đầu
   int               bos_bits;
   double            bos_p[2];
   int               rank;        // số nến bên trái trước khi có đáy thấp hơn (hỗ trợ) / đỉnh cao hơn (kháng cự)
   double            brk_body;    // bản đổi vai: thân nến phá theo chiều phá (ATR nguồn), 0 nếu thân < 60% biên độ
   int               max_age;     // tuổi tối đa (nến nguồn): SIG_LEVEL_AGE, Unicorn SIG_UNI_AGE; chỉ dùng khi max_age_sec = 0
   long              max_age_sec; // tuổi tối đa theo thời gian từ nến gốc (giây), 0 = theo số nến
   int               ref_tf;      // khung đã tinh chỉnh vùng tới; -1 = không tinh chỉnh
   // Vùng Z (411): chờ phá B rồi A (râu cũng tính) mới dùng được; trước đó known_at = SIG_PENDING.
   bool              pend;
   bool              got_b;
   double            z_b, z_a;
   // Unicorn: dừng lỗ theo nhánh thao túng (thân / râu cực trị) và đích DOL (SPEC 23.3 K3).
   double            sl_body, sl_wick, dol;
  };

// Ứng viên Unicorn: đã có DOL, nhánh thao túng quét đáy/đỉnh cũ và nến breaker; chờ dịch chuyển + FVG chồng breaker.
struct SigUniCand
  {
   int               tf, dir;
   datetime          x_time;      // nến cực trị nhánh thao túng
   datetime          k_time;      // nến breaker
   double            bb_lo, bb_hi, dol, sl_body, sl_wick;
   long              until_no;    // hết hạn tìm (số nến nguồn)
  };

// Nhóm đo sức mạnh cản dùng chung cho báo cáo tín hiệu và báo cáo phản ứng tại cản (SPEC 24.3).
string SigDispBucket(double d) { return d<0 ? "khong_ap_dung" : (d<1.0 ? "<1ATR" : (d<2.0 ? "1-2ATR" : (d<3.0 ? "2-3ATR" : ">=3ATR"))); }
string SigBodyBucket(double b) { return b<0 ? "khong_ap_dung" : (b<1.0 ? "<1ATR" : (b<1.5 ? "1-1.5ATR" : ">=1.5ATR")); }
string SigBosBucket(int b) { return b<0 ? "khong_ap_dung" : IntegerToString(b); }
string SigRankBucket(int r) { return r<0 ? "khong_ap_dung" : (r<10 ? "<10" : (r<50 ? "10-50" : (r<200 ? "50-200" : ">=200"))); }
string SigConfBucket(int c) { return c>=3 ? "3+" : IntegerToString(c); }
string SigRefName(int tf) { return tf<0 ? "khong" : SIG_TF_NAME[tf]; }
// Kịch bản (SPEC 23.3): 1 K1 đảo chiều, 2 K2 phá rồi quay lại (đổi vai), 3 K3 Unicorn, 5 K5 tiếp diễn, 6 K2b vùng Z của 411.
string SigScenName(int scen) { return scen==1 ? "K1" : (scen==2 ? "K2" : (scen==3 ? "K3" : (scen==5 ? "K5" : "K2b"))); }

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
   long              m_bar_no[SIG_TF_COUNT];    // số nến khung nguồn đã nhận (tăng mãi; chuỗi chỉ giữ 1.500 nến)
   datetime          m_last_open[SIG_TF_COUNT];
   ScpSeries        *m_cur_s;                   // chuỗi khung nguồn đang xét trong OnSourceBar (tính sức mạnh lúc tạo)
   int               m_cur_tf;
   SigLevel          m_stage;                   // thông tin riêng của vùng Z/Unicorn chép vào cản lúc Add
   bool              m_staged;
   ScpSeries        *m_ser[SIG_TF_COUNT];      // chuỗi các khung (tinh chỉnh vùng); NULL = không có
   SigUniCand        m_uc[];
   int               m_ucn;
   int               m_z_made, m_uni_made;
   int               m_trend;     // chiều của tín hiệu K2 thật gần nhất (+1/-1), 0 chưa có

   void              Log(const SigLevel &z)
     {
      if(m_log==INVALID_HANDLE) return;
      FileWriteString(m_log,IntegerToString(z.id)+";"+(z.fake?"gia":"that")+";"+IntegerToString(z.parent)+";"+
                      SigGroupName(z.group)+";"+SigTypeName(z.type)+";"+(z.role>0?"ho_tro":(z.role<0?"khang_cu":"hai_phia"))+";"+
                      DoubleToString(z.bottom,3)+";"+DoubleToString(z.top,3)+";"+
                      TimeToString(z.origin,TIME_DATE|TIME_MINUTES)+";"+TimeToString(z.known_at,TIME_DATE|TIME_MINUTES)+";"+
                      (z.dead_at>0?TimeToString(z.dead_at,TIME_DATE|TIME_MINUTES):"-")+";"+SigDeadName(z.dead_why)+";"+
                      IntegerToString(z.tests)+";"+DoubleToString(z.disp,2)+";"+DoubleToString(z.body_max,2)+";"+
                      IntegerToString(z.bos)+";"+IntegerToString(z.rank)+";"+DoubleToString(z.brk_body,2)+";"+SigRefName(z.ref_tf)+"\r\n");
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
      // Unicorn giả: dừng lỗ và DOL dời cùng khoảng với vùng.
      double sh=z.bottom-real.bottom;
      if(real.sl_body!=0) z.sl_body=real.sl_body+sh;
      if(real.sl_wick!=0) z.sl_wick=real.sl_wick+sh;
      if(real.dol!=0) z.dol=real.dol+sh;
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
      z.max_age=SIG_LEVEL_AGE;
      z.max_age_sec=(tf>=0 && tf<SIG_TF_COUNT) ? SIG_AGE_SEC[tf] : 0;
      z.ref_tf=-1;
      if(m_staged)
        {
         z.max_age=m_stage.max_age; z.pend=m_stage.pend; z.z_b=m_stage.z_b; z.z_a=m_stage.z_a;
         z.sl_body=m_stage.sl_body; z.sl_wick=m_stage.sl_wick; z.dol=m_stage.dol;
         if(type==SIG_LV_UNI) z.max_age_sec=0;
         m_staged=false;
        }
      Refine(z);
      InitStrength(z);
      if(Push(z)<0) return 0;
      m_created[z.group]++;
      AddFake(z,src_atr,price_now);
      return z.id;
     }

   // Doji SnR (SPEC 22.4): động lực c1 → 1–2 doji/thân nhỏ → động lực c3 cùng chiều đóng vượt cụm doji.
   void              DetectDoji(int tf, ScpSeries *s, double atr, double price_now, int age)
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
         Add(tf,SIG_LV_DOJI,lo,hi,dir,true,c1.open_time,c3.known_at,0,atr,age,price_now,0);
         return;
        }
     }

   // Tinh chỉnh vùng H4/D1/W1 (SPEC 24.5): trong khoảng thời gian của nến mẫu, lấy nến khung nhỏ chứa đỉnh (kháng cự) /
   // đáy (hỗ trợ); vùng mới = [mép thân, đầu râu] của nến đó, nằm trong vùng cũ. Bước 2 lặp lại trong nến vừa chọn.
   // Dừng khi khung nhỏ không có đủ dữ liệu. FVG (khoảng trống, không có nến) và Unicorn giữ nguyên.
   void              Refine(SigLevel &z)
     {
      if(m_cur_s==NULL || z.tf!=m_cur_tf || z.tf<SIG_H4 || z.tf>=SIG_TF_COUNT || z.role==0) return;
      if(z.type==SIG_LV_FVG || z.type==SIG_LV_UNI || z.type==SIG_LV_ROUND || z.type==SIG_LV_PD || z.type==SIG_LV_PW) return;
      int span=(z.type==SIG_LV_CLASSIC || z.type==SIG_LV_GAP) ? 2 : (z.type==SIG_LV_DOJI ? 4 : 1);
      datetime t0=z.origin;
      datetime t1=t0+(datetime)(span*PeriodSeconds(SIG_PERIODS[z.tf]));
      for(int step=0;step<2;step++)
        {
         int rt=SIG_REFINE[z.tf][step];
         if(rt<0 || m_ser[rt]==NULL) break;
         ScpSeries *s2=m_ser[rt];
         int n2=s2.Count();
         if(n2<1 || s2.Bar(0).open_time>t0) break; // khung nhỏ chưa có dữ liệu từ đầu nến mẫu
         int best=-1;
         for(int k=n2-1;k>=0;k--)
           {
            ScpBar b=s2.Bar(k);
            if(b.open_time<t0) break;
            if(b.open_time>=t1) continue;
            if(best<0 || (z.role<0 && b.h>s2.Bar(best).h) || (z.role>0 && b.l<s2.Bar(best).l)) best=k;
           }
         if(best<0) break;
         ScpBar e=s2.Bar(best);
         double lo=(z.role<0) ? MathMax(e.o,e.c) : e.l;
         double hi=(z.role<0) ? e.h : MathMin(e.o,e.c);
         lo=MathMax(lo,z.bottom); hi=MathMin(hi,z.top);
         if(hi<lo) { if(z.role<0) lo=hi; else hi=lo; }
         z.bottom=lo; z.top=hi; z.ref_tf=rt;
         t0=e.open_time; t1=t0+(datetime)PeriodSeconds(SIG_PERIODS[rt]);
        }
      if(z.lvl>0 && (z.lvl<z.bottom || z.lvl>z.top)) z.lvl=0; // mức thân nằm ngoài vùng mới: chạm ở mép gần
     }

   // Số thứ tự nến có chỉ số k trong chuỗi khung nguồn đang xét.
   long              BarNoAt(int tf, ScpSeries *s, int k) { return m_bar_no[tf]-(s.Count()-1-k); }

   // Thân nến theo chiều dir (ATR), 0 nếu ngược chiều hoặc thân < 60% biên độ.
   double            MomoBody(const ScpBar &b, int dir, double atr)
     {
      double body=dir*(b.c-b.o), range=b.h-b.l;
      if(atr<=0 || body<=0 || range<=0 || body<SIG_MOMO_FULL*range) return 0;
      return body/atr;
     }

   // Cập nhật lực bật, thân động lực và phá cấu trúc của cản với nến k của chuỗi (k sau nến gốc).
   void              StepStrength(SigLevel &z, ScpSeries *s, int k)
     {
      ScpBar b=s.Bar(k);
      long d=BarNoAt(z.tf,s,k)-z.origin_no;
      if(d<=SIG_DISP_BARS)
        {
         double away=(z.role>0) ? b.h-z.top : z.bottom-b.l;
         if(z.atr_src>0) z.disp=MathMax(z.disp,away/z.atr_src);
         z.body_max=MathMax(z.body_max,MomoBody(b,z.role,z.atr_src));
        }
      if(z.tests==0 && d<=SIG_BOS_BARS)
         for(int j=0;j<2;j++)
            if(z.bos_p[j]>0 && ((z.role>0 && b.c>z.bos_p[j]) || (z.role<0 && b.c<z.bos_p[j]))) z.bos_bits|=(1<<j);
      z.bos=((z.bos_bits&1)!=0 ? 1 : 0)+((z.bos_bits&2)!=0 ? 1 : 0);
     }

   // Sức mạnh lúc tạo từ các nến đã có (SPEC 24.1). Chỉ cản có vai rõ của khung nguồn đang xét.
   void              InitStrength(SigLevel &z)
     {
      z.atr_src=0; z.origin_no=0; z.disp=-1; z.body_max=-1; z.bos=-1; z.bos_bits=0; z.bos_p[0]=0; z.bos_p[1]=0;
      z.rank=-1; z.brk_body=0;
      ScpSeries *s=m_cur_s;
      if(s==NULL || z.tf!=m_cur_tf || z.role==0 || z.type==SIG_LV_ROUND || z.type==SIG_LV_PD || z.type==SIG_LV_PW) return;
      int n=s.Count(), k0=-1;
      for(int k=n-1;k>=MathMax(0,n-1-SIG_LEVEL_AGE);k--) if(s.Bar(k).open_time==z.origin) { k0=k; break; }
      if(k0<0) return;
      z.atr_src=s.Atr();
      z.origin_no=BarNoAt(z.tf,s,k0);
      z.disp=0; z.body_max=MomoBody(s.Bar(k0),z.role,z.atr_src); z.bos=0;
      // Hai đỉnh (hỗ trợ) / đáy (kháng cự) gần nhất trước nến gốc, nằm phía rời cản.
      int got=0;
      for(int i=s.PivotCount()-1;i>=0 && got<2;i--)
        {
         ScpPivot p=s.Pivot(i);
         if(p.ambiguous || p.bar_time>=z.origin || p.is_high!=(z.role>0)) continue;
         if((z.role>0 && p.price>z.top) || (z.role<0 && p.price<z.bottom)) z.bos_p[got++]=p.price;
        }
      for(int k=k0+1;k<n;k++) StepStrength(z,s,k);
      // Độ lớn đỉnh/đáy: số nến bên trái trước khi có đáy thấp hơn mép xa (hỗ trợ) / đỉnh cao hơn (kháng cự).
      z.rank=0;
      for(int k=k0-1;k>=MathMax(0,k0-SIG_RANK_CAP);k--)
        {
         ScpBar b=s.Bar(k);
         if((z.role>0 && b.l<z.bottom) || (z.role<0 && b.h>z.top)) break;
         z.rank++;
        }
     }

   // Nến nguồn mới đóng: cập nhật sức mạnh các cản thật của khung đó còn trong cửa sổ đo, chép sang cản giả con.
   void              UpdateStrength(int tf, ScpSeries *s)
     {
      int k=s.Count()-1;
      for(int i=0;i<m_n;i++)
        {
         if(m_lv[i].fake || m_lv[i].flip>0 || m_lv[i].tf!=tf || m_lv[i].disp<0 || !m_lv[i].alive) continue;
         long d=m_bar_no[tf]-m_lv[i].origin_no;
         if(d<1 || d>SIG_BOS_BARS) continue;
         double d0=m_lv[i].disp, b0=m_lv[i].body_max;
         int s0=m_lv[i].bos;
         StepStrength(m_lv[i],s,k);
         if(m_lv[i].disp==d0 && m_lv[i].body_max==b0 && m_lv[i].bos==s0) continue;
         for(int j=0;j<m_n;j++)
            if(m_lv[j].fake && m_lv[j].flip==0 && m_lv[j].parent==m_lv[i].id)
              { m_lv[j].disp=m_lv[i].disp; m_lv[j].body_max=m_lv[i].body_max; m_lv[j].bos=m_lv[i].bos; }
        }
     }

   int               BarIdx(ScpSeries *s, datetime t)
     {
      int n=s.Count();
      for(int k=n-1;k>=MathMax(0,n-1-SIG_LEVEL_AGE);k--) if(s.Bar(k).open_time==t) return k;
      return -1;
     }

   // Vùng Z của 411 (SPEC 23.2 L5, 411 phần 1 mục 3–4). p2 = đỉnh 2 của M (bán) / đáy 2 của W (mua) vừa xác nhận.
   // A, đỉnh 1, B là 3 đỉnh/đáy xen kẽ trước đó; bán cần B > A, mua cần B < A. Z = nến đầu tiên ở cụm đỉnh 2 có đáy thấp hơn
   // đáy nến trước (mua: đỉnh cao hơn đỉnh nến trước); vùng = cả nến Z. Chưa lọc HSL/nhấn chìm (cần đo).
   void              DetectZone(int tf, ScpSeries *s, int i, double atr, double price_now, int age)
     {
      ScpPivot p2=s.Pivot(i);
      bool sell=p2.is_high;
      int iB=-1, iP1=-1, iA=-1;
      for(int j=i-1;j>=0;j--)
        {
         ScpPivot q=s.Pivot(j);
         if(q.ambiguous) continue;
         if(iB<0) { if(q.is_high!=sell) iB=j; continue; }
         if(iP1<0) { if(q.is_high==sell) iP1=j; continue; }
         if(q.is_high!=sell) { iA=j; break; }
        }
      if(iA<0) return;
      double B=s.Pivot(iB).price, A=s.Pivot(iA).price;
      if((sell && B<=A) || (!sell && B>=A)) return;
      int kB=BarIdx(s,s.Pivot(iB).bar_time), kP=BarIdx(s,p2.bar_time), n=s.Count();
      if(kB<0 || kP<0) return;
      for(int k=MathMax(kB+1,kP-1);k<n;k++)
        {
         ScpBar z=s.Bar(k), zp=s.Bar(k-1);
         if(sell ? (z.l>=zp.l) : (z.h<=zp.h)) continue;
         ZeroMemory(m_stage);
         m_stage.max_age=SIG_LEVEL_AGE; m_stage.pend=true; m_stage.z_b=B; m_stage.z_a=A;
         m_staged=true;
         if(Add(tf,SIG_LV_Z,z.l,z.h,sell ? -1 : 1,false,z.open_time,SIG_PENDING,0,atr,age,price_now,0)>0) m_z_made++;
         m_staged=false;
         return;
        }
     }

   // DOL cho Unicorn: nhóm hai đỉnh (mua) / đáy (bán) bằng nhau tương đối (chênh <= tol) phía trước giá, chưa bị giá vượt;
   // lấy nhóm gần giá nhất. 0 = không có (Unicorn tr.3; SPEC 23.3 K3).
   double            EqualDol(ScpSeries *s, int dir, double price, double tol, datetime now)
     {
      int n=s.Count();
      if(n<3 || tol<=0) return 0;
      int k0=MathMax(0,n-1-SIG_LEVEL_AGE);
      // Cực trị các nến sau nến k (đỉnh cao nhất với mua, đáy thấp nhất với bán).
      double after[];
      ArrayResize(after,n);
      after[n-1]=(dir>0) ? -DBL_MAX : DBL_MAX;
      for(int k=n-2;k>=k0;k--)
        {
         ScpBar b=s.Bar(k+1);
         after[k]=(dir>0) ? MathMax(after[k+1],b.h) : MathMin(after[k+1],b.l);
        }
      int idx[]; double pr[];
      int m=0;
      for(int i=0;i<s.PivotCount();i++)
        {
         ScpPivot q=s.Pivot(i);
         if(q.ambiguous || q.is_high!=(dir>0) || q.known_at>now) continue;
         int k=BarIdx(s,q.bar_time);
         if(k<k0) continue;
         ArrayResize(idx,m+1); ArrayResize(pr,m+1);
         idx[m]=k; pr[m]=q.price; m++;
        }
      double best=0;
      for(int a=0;a<m;a++)
         for(int b=a+1;b<m;b++)
           {
            if(MathAbs(pr[a]-pr[b])>tol) continue;
            double lvl=(dir>0) ? MathMax(pr[a],pr[b]) : MathMin(pr[a],pr[b]);
            if((dir>0 && lvl<=price) || (dir<0 && lvl>=price)) continue;
            int first=MathMin(idx[a],idx[b]);
            if((dir>0 && after[first]>lvl) || (dir<0 && after[first]<lvl)) continue;
            if(best==0 || (dir>0 && lvl<best) || (dir<0 && lvl>best)) best=lvl;
           }
      return best;
     }

   // Nhánh thao túng (SPEC 23.3 K3): x vừa xác nhận là đáy thấp hơn đáy trước (mua) / đỉnh cao hơn đỉnh trước (bán),
   // có DOL ở phía ngược lại. Nến breaker = nến tăng (mua) / giảm (bán) cuối cùng từ gốc nhánh G tới x.
   void              UniCandidate(int tf, ScpSeries *s, int i, double atr, datetime now)
     {
      ScpPivot x=s.Pivot(i);
      int dir=x.is_high ? -1 : 1;
      int iPrev=-1, iG=-1;
      for(int j=i-1;j>=0;j--)
        {
         ScpPivot q=s.Pivot(j);
         if(q.ambiguous) continue;
         if(q.is_high==x.is_high) { iPrev=j; break; }
         if(iG<0) iG=j;
        }
      if(iPrev<0 || iG<0) return;
      double prev=s.Pivot(iPrev).price;
      if((dir>0 && x.price>=prev) || (dir<0 && x.price<=prev)) return;
      int kG=BarIdx(s,s.Pivot(iG).bar_time), kX=BarIdx(s,x.bar_time);
      if(kG<0 || kX<0) return;
      int kk=-1;
      double body=(dir>0) ? DBL_MAX : -DBL_MAX;
      for(int k=kX;k>=kG;k--)
        {
         ScpBar b=s.Bar(k);
         if(kk<0 && dir*(b.c-b.o)>0) kk=k;
         body=(dir>0) ? MathMin(body,MathMin(b.o,b.c)) : MathMax(body,MathMax(b.o,b.c));
        }
      if(kk<0) return;
      double dol=EqualDol(s,dir,s.LastBar().c,SIG_UNI_EQ_ATR*atr,now);
      if(dol==0) return;
      ScpBar kb=s.Bar(kk);
      if(m_ucn>=ArraySize(m_uc)) ArrayResize(m_uc,m_ucn+16);
      SigUniCand c;
      c.tf=tf; c.dir=dir; c.x_time=x.bar_time; c.k_time=kb.open_time;
      c.bb_lo=kb.l; c.bb_hi=kb.h; c.dol=dol; c.sl_body=body; c.sl_wick=x.price;
      c.until_no=m_bar_no[tf]+SIG_UNI_AGE;
      m_uc[m_ucn++]=c;
     }

   // Ứng viên đủ dịch chuyển (nến đóng qua mép xa breaker) và FVG chồng breaker: tạo vùng Unicorn = hợp breaker ∪ FVG.
   void              UniEvaluate(int tf, ScpSeries *s, double atr, double price_now, int age)
     {
      int n=s.Count();
      for(int q=m_ucn-1;q>=0;q--)
        {
         if(m_uc[q].tf!=tf) continue;
         SigUniCand c=m_uc[q];
         int kX=BarIdx(s,c.x_time);
         bool drop=(m_bar_no[tf]>c.until_no || kX<0);
         int j=-1;
         for(int k=kX+1;!drop && k<n;k++)
           {
            ScpBar b=s.Bar(k);
            if((c.dir>0 && b.c>c.bb_hi) || (c.dir<0 && b.c<c.bb_lo)) { j=k; break; }
           }
         int f3=-1;
         double lo=0, hi=0;
         for(int k=kX;!drop && j>=0 && k+2<n;k++)
           {
            ScpBar c1=s.Bar(k), c2=s.Bar(k+1), c3=s.Bar(k+2);
            if(c.dir*(c2.c-c2.o)<=0) continue;
            double glo=(c.dir>0) ? c1.h : c3.h, ghi=(c.dir>0) ? c3.l : c1.l;
            if(ghi<=glo) continue;
            if(MathMin(c.bb_hi,ghi)<=MathMax(c.bb_lo,glo)) continue; // FVG phải chồng breaker
            f3=k+2; lo=MathMin(c.bb_lo,glo); hi=MathMax(c.bb_hi,ghi);
            break;
           }
         if(!drop && f3>=0)
           {
            ZeroMemory(m_stage);
            m_stage.max_age=SIG_UNI_AGE; m_stage.sl_body=c.sl_body; m_stage.sl_wick=c.sl_wick; m_stage.dol=c.dol;
            m_staged=true;
            datetime known=s.Bar(MathMax(j,f3)).known_at;
            if(Add(tf,SIG_LV_UNI,lo,hi,c.dir,false,c.k_time,known,0,atr,age,price_now,0)>0) m_uni_made++;
            m_staged=false;
            drop=true;
           }
         if(drop) { m_uc[q]=m_uc[m_ucn-1]; m_ucn--; }
        }
     }

   // Bản đổi vai của cản i sau khi bị phá (Rare SnR SBR/RBS): cùng hình học, vai ngược, mới ở phía kia.
   void              AddFlip(int i, datetime known, int def, double brk)
     {
      for(int j=0;j<m_n;j++)
         if(m_lv[j].parent==m_lv[i].id && m_lv[j].flip==m_lv[i].flip+1 && m_lv[j].fake==m_lv[i].fake && m_lv[j].alive)
           { m_lv[j].flip_def|=def; return; }
      SigLevel z=m_lv[i];
      z.id=m_next++;
      z.parent=m_lv[i].id;
      z.role=-m_lv[i].role;
      z.flip=m_lv[i].flip+1; z.flip_def=def; z.wick_broken=false;
      z.brk_body=brk; // sức mạnh còn lại giữ của cản gốc
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
      ArrayInitialize(m_bar_no,0); ArrayInitialize(m_last_open,0);
      m_cur_s=NULL; m_cur_tf=-1;
      m_staged=false; m_ucn=0; m_z_made=0; m_uni_made=0;
      for(int t=0;t<SIG_TF_COUNT;t++) m_ser[t]=NULL;
      ArrayResize(m_uc,0,16);
      ArrayResize(m_lv,0,4096); ArrayResize(m_round_keys,0,256);
     }

   void              SetLog(int fh) { m_log=fh; }
   void              SetSeries(int tf, ScpSeries *s) { if(tf>=0 && tf<SIG_TF_COUNT) m_ser[tf]=s; }
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
   int               ZonesMade() { return m_z_made; }
   int               UnicornsMade() { return m_uni_made; }

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
      UpdateStrength(tf,s);
      m_cur_s=s; m_cur_tf=tf;
      int age=(int)m_bar_no[tf];
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
            Add(tf,SIG_LV_PIVOT,lo,hi,p.is_high ? -1 : 1,true,src.open_time,p.known_at,0,atr,age,price_now,0);
            // Classic A (đỉnh) / V (đáy) có nến pivot là c1 hoặc c2 (SPEC 23.2 L2; lọc đề xuất).
            if(tf!=SIG_M5)
               for(int c1i=b-1;c1i<=b;c1i++)
                 {
                  if(c1i<0 || c1i+1>=n) continue;
                  ScpBar c1=s.Bar(c1i), c2=s.Bar(c1i+1);
                  if(p.is_high && c1.c>c1.o && c2.c<c2.o)
                     Add(tf,SIG_LV_CLASSIC,c1.c,MathMax(c1.h,c2.h),-1,false,c1.open_time,p.known_at,0,atr,age,price_now,0,c1.c);
                  if(!p.is_high && c1.c<c1.o && c2.c>c2.o)
                     Add(tf,SIG_LV_CLASSIC,MathMin(c1.l,c2.l),c1.c,1,false,c1.open_time,p.known_at,0,atr,age,price_now,0,c1.c);
                 }
            break;
           }
         if(tf>=SIG_M15) DetectZone(tf,s,i,atr,price_now,age);
         if(tf==SIG_M5 || tf==SIG_M15) UniCandidate(tf,s,i,atr,last.known_at);
        }
      if(tf==SIG_M5 || tf==SIG_M15) UniEvaluate(tf,s,atr,price_now,age);
      if(tf==SIG_M5) { m_cur_s=NULL; return; } // cản tạm M5 chỉ dùng vùng đỉnh/đáy (và Unicorn)
      DetectDoji(tf,s,atr,price_now,age);
      // Gap SnR: hai nến cùng màu, ít nhất một nến thân >= 0,6 ATR (lọc đề xuất); mức C(c1), vùng [LL, UL] (SPEC 23.2 L3).
      ScpBar g1=s.Bar(n-2), g2=s.Bar(n-1);
      bool strong=(MathAbs(g1.c-g1.o)>=SIG_MOMO_BODY_ATR*atr || MathAbs(g2.c-g2.o)>=SIG_MOMO_BODY_ATR*atr);
      if(strong && g1.c<g1.o && g2.c<g2.o)
         Add(tf,SIG_LV_GAP,g1.l,MathMax(g2.h,g1.c),-1,false,g1.open_time,g2.known_at,0,atr,age,price_now,0,g1.c);
      if(strong && g1.c>g1.o && g2.c>g2.o)
         Add(tf,SIG_LV_GAP,MathMin(g2.l,g1.c),g1.h,1,false,g1.open_time,g2.known_at,0,atr,age,price_now,0,g1.c);
      // FVG ba nến, nến giữa cùng chiều khoảng trống, bề rộng tối thiểu.
      ScpBar a=s.Bar(n-3), mid=s.Bar(n-2), c=s.Bar(n-1);
      double min_w=MathMax(2.0*m_tick,SCP_K_BUFFER*atr);
      if(c.l>a.h && mid.c>mid.o && c.l-a.h>=min_w) Add(tf,SIG_LV_FVG,a.h,c.l,1,false,a.open_time,c.known_at,0,atr,age,price_now,0);
      if(c.h<a.l && mid.c<mid.o && a.l-c.h>=min_w) Add(tf,SIG_LV_FVG,c.h,a.l,-1,false,a.open_time,c.known_at,0,atr,age,price_now,0);
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
              { Add(tf,SIG_LV_OB,ob.l,ob.h,dir,false,ob.open_time,last.known_at,0,atr,age,price_now,0); break; }
           }
      m_cur_s=NULL;
     }

   // Cản của khung nguồn hết hiệu lực: nến khung đó đóng vượt mép xa thêm eps, hoặc quá tuổi.
   void              ExpireBySource(int tf, ScpSeries *s)
     {
      if(s==NULL || s.Count()<1) return;
      ScpBar b=s.LastBar();
      double eps=SCP_K_BUFFER*s.Atr();
      int n=s.Count();
      // Đếm nến nguồn mới (tăng mãi): tuổi cản không phụ thuộc số nến chuỗi còn giữ (tối đa 1.500).
      for(int k=n-1;k>=0 && s.Bar(k).open_time>m_last_open[tf];k--) m_bar_no[tf]++;
      m_last_open[tf]=b.open_time;
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
            if(flippable && m_lv[i].known_at<=b.open_time) AddFlip(i,b.known_at,1,MomoBody(b,-side,s.Atr()));
            Kill(i,b.close_time,1);
            continue;
           }
         if(flippable && !m_lv[i].wick_broken && m_lv[i].known_at<=b.open_time &&
            ((side>0 && b.l<m_lv[i].bottom-eps) || (side<0 && b.h>m_lv[i].top+eps)))
           {
            m_lv[i].wick_broken=true;
            AddFlip(i,b.known_at,2,MomoBody(b,-side,s.Atr()));
           }
         // Vùng Z: phá B rồi A (râu cũng tính, 411 tr.4) thì dùng được từ lúc nến đó đóng; cản giả chép theo cản thật.
         if(m_lv[i].alive && m_lv[i].pend && !m_lv[i].fake)
           {
            int d=m_lv[i].role; // -1 bán (M): phá xuống; +1 mua (W): phá lên
            if(!m_lv[i].got_b && ((d<0 && b.l<m_lv[i].z_b) || (d>0 && b.h>m_lv[i].z_b))) m_lv[i].got_b=true;
            if(m_lv[i].got_b && ((d<0 && b.l<m_lv[i].z_a) || (d>0 && b.h>m_lv[i].z_a)))
              {
               m_lv[i].pend=false; m_lv[i].known_at=b.known_at;
               for(int j=0;j<m_n;j++)
                  if(m_lv[j].fake && m_lv[j].parent==m_lv[i].id && m_lv[j].pend) { m_lv[j].pend=false; m_lv[j].known_at=b.known_at; }
              }
           }
         if(m_lv[i].max_age_sec>0 ? (b.close_time-m_lv[i].origin>m_lv[i].max_age_sec)
                                  : (m_bar_no[tf]-m_lv[i].age_start>m_lv[i].max_age)) Kill(i,b.close_time,2);
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
         if(htf==(m_lv[i].group==SIG_G_M5TAM) || m_lv[i].type==SIG_LV_UNI) continue;
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
