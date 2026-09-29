// SigTrack.mqh — theo dõi tín hiệu và đối chứng trên từng tick cho công cụ đo (SPEC mục 22.3).
// Chỉ tính trên báo giá do bên gọi đưa vào; không đọc MT5, không gửi lệnh.
#ifndef SIG_TRACK_MQH
#define SIG_TRACK_MQH

#define SIG_NR 6          // đua dừng/chốt: 1R, 1,5R, 2R, 3R, cản khung lớn kế tiếp, DOL
#define SIG_NS 6          // chốt hai phần: phần đầu {1R, 1,5R, cản M5} × phần sau {cản khung lớn, DOL}
#define SIG_NH 5          // quãng đi thuận/ngược sau 1, 5, 15, 60, 240 phút
#define SIG_T_HTF 0       // chỉ số đích trong mảng k[]
#define SIG_T_M5 1
#define SIG_T_DOL 2
#define SIG_OPEN 0
#define SIG_WIN 1
#define SIG_LOSS -1
#define SIG_TIMEOUT 2     // hết thời gian theo dõi hoặc sắp nghỉ sàn: đóng ở giá thoát hiện tại
#define SIG_BE 3          // phần còn lại ra ở giá vào sau khi đã chốt phần đầu
#define SIG_NA -9         // cấu hình không áp dụng (không có đích)

enum ENUM_SIG_KIND { SIG_K_SIG=0, SIG_K_REV=1, SIG_K_RT=2, SIG_K_FAKE=3 };

const double SIG_RACE_K[4] = {1.0, 1.5, 2.0, 3.0};
const int    SIG_HORIZON_MIN[SIG_NH] = {1, 5, 15, 60, 240};

// Đặc điểm của tín hiệu gốc; đối chứng chép nguyên để chia nhóm giống hệt tín hiệu.
struct SigFeatures
  {
   int               etf;        // 0 M1, 1 M5
   int               group;      // mã nhóm cản (SigLevels)
   int               ltype;      // loại cản
   int               tier;       // bậc khối lượng 0..4 (đã xét trùng cản)
   int               conf;       // số cản khác trùng tại lúc chạm
   int               reaction;   // 1 P1, 2 P2, 3 P3
   bool              strict;     // P1/P2 đạt cả điều kiện đóng vượt mép gần
   bool              minor;      // cản tạm M5
   int               test_no;    // 0 lần kiểm tra đầu, 1 lần 2, ...
   bool              wick;       // cản có râu (đỉnh/đáy, Doji SnR)
   int               var_moc;    // kiểu mốc chạm: 0 thân/mép gần, 1 giữa râu, 2 đỉnh/đáy râu
   int               var_sl;     // kiểu dừng: 0 sát sau râu, 1 thêm 0,3 ATR M5, 2 thêm 0,5 ATR M5
   int               scen;       // kịch bản: 1 K1 đảo chiều ở cản mới, 2 K2 phá rồi quay lại, 5 K5 tiếp diễn (SPEC 23.3)
   int               flip_def;   // K2/K5: 1 phá bằng thân, 2 phá bằng râu, 3 cả hai
   bool              wick_broken;// K1: râu đã vượt mép xa (không hợp lệ theo định nghĩa phá bằng râu)
   int               news;       // -1 thiếu lịch, 0 xa tin, 1 gần tin
   int               bars_after; // số nến khung vào từ chạm tới phản ứng
   int               hour;       // giờ sàn lúc vào
   double            spread;
   double            atr;        // ATR khung vào lúc chạm
   double            cost_r;     // (spread + 2·trượt)/R
  };

struct SigRec
  {
   long              id;
   int               kind;
   long              parent;
   datetime          t0;
   int               dir;
   double            entry;      // giá khớp giả định: mua Ask, bán Bid
   double            r;          // khoảng tới dừng theo giá thoát (dương)
   double            k[3];       // đích theo bội số R (cản khung lớn, cản M5, DOL); 0 là không có
   int               rs[SIG_NR];
   double            rr[SIG_NR];
   int               ss[SIG_NS];
   double            sr[SIG_NS];
   bool              s1[SIG_NS];
   double            mfe, mae;
   double            hf[SIG_NH], ha[SIG_NH];
   int               hn;
   double            band_lo, band_hi; // giữa hai mức này không có gì đổi: bỏ qua bước tính (chỉ để chạy nhanh)
   SigFeatures       f;
  };

struct SigSchedule
  {
   datetime          at;
   long              parent;
   int               dir;
   double            r;
   double            k[3];
   SigFeatures       f;
  };

// Đích phần đầu và phần sau của cấu hình chốt hai phần j (bội số R); 0 là không có.
double SigSplitFirst(const SigRec &x, int j)
  {
   int a=j%3;
   return (a==0) ? 1.0 : (a==1 ? 1.5 : x.k[SIG_T_M5]);
  }
double SigSplitSecond(const SigRec &x, int j) { return (j<3) ? x.k[SIG_T_HTF] : x.k[SIG_T_DOL]; }
double SigRaceTarget(const SigRec &x, int i)
  {
   if(i<4) return SIG_RACE_K[i];
   return (i==4) ? x.k[SIG_T_HTF] : x.k[SIG_T_DOL];
  }

class SigTracker
  {
private:
   SigRec            m_open[];
   int               m_n;
   SigRec            m_done[];
   int               m_dn;
   SigSchedule       m_sched[];
   int               m_sn;
   long              m_next_id;
   ulong             m_seed;
   int               m_max_hold_min;
   int               m_rt_copies;
   int               m_rt_missed;
   int               m_rt_made;
   datetime          m_next_sched;

   void              Resolve(SigRec &x, double move, int state)
     {
      for(int i=0;i<SIG_NR;i++)
         if(x.rs[i]==SIG_OPEN) { x.rs[i]=state; x.rr[i]=move; }
      for(int j=0;j<SIG_NS;j++)
         if(x.ss[j]==SIG_OPEN) { x.ss[j]=state; x.sr[j]+=(x.s1[j] ? 0.5 : 1.0)*move; }
     }

   bool              AllResolved(const SigRec &x)
     {
      for(int i=0;i<SIG_NR;i++) if(x.rs[i]==SIG_OPEN) return false;
      for(int j=0;j<SIG_NS;j++) if(x.ss[j]==SIG_OPEN) return false;
      return true;
     }

   void              Finish(int idx)
     {
      for(int h=m_open[idx].hn;h<SIG_NH;h++) { m_open[idx].hf[h]=m_open[idx].mfe; m_open[idx].ha[h]=m_open[idx].mae; }
      m_open[idx].hn=SIG_NH;
      if(m_dn>=ArraySize(m_done)) ArrayResize(m_done,m_dn+4096);
      m_done[m_dn++]=m_open[idx];
      m_open[idx]=m_open[m_n-1];
      m_n--;
     }

   // Dừng là lệnh dừng: khớp ở giá chạm (có thể xấu hơn -1R). Chốt là lệnh giới hạn: khớp đúng mức.
   void              Step(SigRec &x, double move)
     {
      if(move>x.mfe) x.mfe=move;
      if(move<x.mae) x.mae=move;
      for(int i=0;i<SIG_NR;i++)
        {
         if(x.rs[i]!=SIG_OPEN) continue;
         double k=SigRaceTarget(x,i);
         if(move<=-1.0) { x.rs[i]=SIG_LOSS; x.rr[i]=move; }
         else if(move>=k) { x.rs[i]=SIG_WIN; x.rr[i]=k; }
        }
      for(int j=0;j<SIG_NS;j++)
        {
         if(x.ss[j]!=SIG_OPEN) continue;
         double t1=SigSplitFirst(x,j), t2=SigSplitSecond(x,j);
         bool single=(t2<=t1); // đích xa tới trước đích gần: đóng hết ở đích xa, không dời đích
         if(!x.s1[j])
           {
            if(move<=-1.0) { x.ss[j]=SIG_LOSS; x.sr[j]=move; }
            else if(single && move>=t2) { x.ss[j]=SIG_WIN; x.sr[j]=t2; }
            else if(!single && move>=t1) { x.s1[j]=true; x.sr[j]=0.5*t1; }
           }
         if(x.ss[j]==SIG_OPEN && x.s1[j])
           {
            // Sau phần đầu, dừng phần còn lại ở giá vào (SPEC 22.1 mục 7).
            if(move<=0.0) { x.ss[j]=SIG_BE; x.sr[j]+=0.5*move; }
            else if(move>=t2) { x.ss[j]=SIG_WIN; x.sr[j]+=0.5*t2; }
           }
        }
     }

   // Dải giá không làm đổi trạng thái: dưới là max(cực trị ngược, 0 nếu phần còn lại đang chờ dừng ở giá vào),
   // trên là cực trị thuận (mọi đích còn chờ đều nằm trên đó).
   void              Band(SigRec &x)
     {
      double lo=x.mae, hi=x.mfe;
      for(int j=0;j<SIG_NS;j++) if(x.ss[j]==SIG_OPEN && x.s1[j]) lo=MathMax(lo,0.0);
      x.band_lo=lo; x.band_hi=hi;
     }

   double            Rand01()
     {
      m_seed=m_seed*6364136223846793005+1442695040888963407;
      return (double)(m_seed>>11)/9007199254740992.0;
     }

public:
                     SigTracker() { Init(1,1440,3); }

   void              Init(ulong seed, int max_hold_min, int rt_copies)
     {
      m_n=0; m_dn=0; m_sn=0; m_next_id=1;
      m_seed=seed; m_max_hold_min=max_hold_min; m_rt_copies=MathMin(rt_copies,10);
      m_rt_missed=0; m_rt_made=0; m_next_sched=D'3000.01.01';
      ArrayResize(m_open,0,1024); ArrayResize(m_done,0,8192); ArrayResize(m_sched,0,1024);
     }

   int               OpenCount() { return m_n; }
   int               DoneCount() { return m_dn; }
   int               RtMissed() { return m_rt_missed; }
   int               RtMade() { return m_rt_made; }
   SigRec            Done(int i) { return m_done[i]; }

   // Mở một bản ghi ở báo giá hiện tại. r là khoảng tới dừng theo giá thoát (đã gồm spread với lệnh bán).
   long              Open(int kind, long parent, datetime now, int dir, double bid, double ask,
                          double r, const double &k[], const SigFeatures &f)
     {
      if((dir!=1 && dir!=-1) || r<=0 || bid<=0 || ask<bid) return 0;
      SigRec x;
      ZeroMemory(x);
      x.id=m_next_id++;
      x.kind=kind; x.parent=parent; x.t0=now; x.dir=dir;
      x.entry=(dir>0) ? ask : bid;
      x.r=r;
      for(int t=0;t<3;t++) x.k[t]=(k[t]>0) ? k[t] : 0;
      for(int i=0;i<SIG_NR;i++) x.rs[i]=(SigRaceTarget(x,i)>0) ? SIG_OPEN : SIG_NA;
      for(int j=0;j<SIG_NS;j++)
         x.ss[j]=(SigSplitFirst(x,j)>0 && SigSplitSecond(x,j)>0) ? SIG_OPEN : SIG_NA;
      x.f=f;
      x.band_lo=0; x.band_hi=0;
      if(m_n>=ArraySize(m_open)) ArrayResize(m_open,m_n+1024);
      m_open[m_n++]=x;
      return x.id;
     }

   // Tín hiệu gốc kèm đánh ngược cùng lúc và các lần vào ngẫu nhiên cùng giờ trong ngày 1–10 ngày sau.
   long              OpenWithControls(datetime now, int dir, double bid, double ask,
                                      double r, const double &k[], const SigFeatures &f)
     {
      long id=Open(SIG_K_SIG,0,now,dir,bid,ask,r,k,f);
      if(id<=0) return 0;
      Open(SIG_K_REV,id,now,-dir,bid,ask,r,k,f);
      bool used[10]; ArrayInitialize(used,false);
      for(int c=0;c<m_rt_copies;c++)
        {
         int d=1;
         for(int tries=0;tries<50;tries++)
           {
            d=1+(int)MathFloor(Rand01()*10.0);
            if(d>10) d=10;
            if(!used[d-1]) break;
           }
         used[d-1]=true;
         if(m_sn>=ArraySize(m_sched)) ArrayResize(m_sched,m_sn+1024);
         m_sched[m_sn].at=now+(datetime)(d*86400);
         m_sched[m_sn].parent=id;
         m_sched[m_sn].dir=dir;
         m_sched[m_sn].r=r;
         for(int t=0;t<3;t++) m_sched[m_sn].k[t]=k[t];
         m_sched[m_sn].f=f;
         if(m_sched[m_sn].at<m_next_sched) m_next_sched=m_sched[m_sn].at;
         m_sn++;
        }
      return id;
     }

   // Cập nhật mọi bản ghi mở bằng báo giá mới. `session_close_soon`: đóng tất cả ở giá thoát hiện tại (không giữ qua nghỉ).
   void              Update(datetime now, double bid, double ask, bool session_close_soon)
     {
      // Đối chứng thời gian ngẫu nhiên tới giờ: mở ở báo giá đầu tiên; quá 120 giây sau mốc là thiếu dữ liệu (sàn nghỉ).
      for(int s=m_sn-1;s>=0 && now>=m_next_sched;s--)
        {
         if(now<m_sched[s].at) continue;
         if(now-m_sched[s].at<=120 && !session_close_soon)
           {
            Open(SIG_K_RT,m_sched[s].parent,now,m_sched[s].dir,bid,ask,m_sched[s].r,m_sched[s].k,m_sched[s].f);
            m_rt_made++;
           }
         else m_rt_missed++;
         m_sched[s]=m_sched[m_sn-1];
         m_sn--;
        }
      if(now>=m_next_sched)
        {
         m_next_sched=D'3000.01.01';
         for(int s=0;s<m_sn;s++) if(m_sched[s].at<m_next_sched) m_next_sched=m_sched[s].at;
        }
      for(int i=m_n-1;i>=0;i--)
        {
         double exitp=(m_open[i].dir>0) ? bid : ask;
         double move=m_open[i].dir*(exitp-m_open[i].entry)/m_open[i].r;
         bool timeout=(now>=m_open[i].t0+(datetime)(m_max_hold_min*60));
         bool horizon=(m_open[i].hn<SIG_NH && now>=m_open[i].t0+(datetime)(SIG_HORIZON_MIN[m_open[i].hn]*60));
         if(!session_close_soon && !timeout && !horizon && move>m_open[i].band_lo && move<m_open[i].band_hi) continue;
         Step(m_open[i],move);
         Band(m_open[i]);
         while(m_open[i].hn<SIG_NH && now>=m_open[i].t0+(datetime)(SIG_HORIZON_MIN[m_open[i].hn]*60))
           {
            m_open[i].hf[m_open[i].hn]=m_open[i].mfe;
            m_open[i].ha[m_open[i].hn]=m_open[i].mae;
            m_open[i].hn++;
           }
         if(session_close_soon || timeout)
           {
            Resolve(m_open[i],move,SIG_TIMEOUT);
            Finish(i);
            continue;
           }
         if(AllResolved(m_open[i]) && m_open[i].hn>=SIG_NH) Finish(i);
        }
     }

   // Kết thúc lượt đo: bản ghi còn mở đóng ở giá thoát cuối; lịch đối chứng chưa tới giờ tính là thiếu.
   void              CloseAll(double bid, double ask)
     {
      for(int i=m_n-1;i>=0;i--)
        {
         double exitp=(m_open[i].dir>0) ? bid : ask;
         double move=m_open[i].dir*(exitp-m_open[i].entry)/m_open[i].r;
         Resolve(m_open[i],move,SIG_TIMEOUT);
         Finish(i);
        }
      m_rt_missed+=m_sn;
      m_sn=0;
     }
  };

#endif // SIG_TRACK_MQH
