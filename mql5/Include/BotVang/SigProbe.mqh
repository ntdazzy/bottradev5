// SigProbe.mqh — đo phản ứng của giá tại cản, tách khỏi cách vào lệnh (SPEC mục 24.3).
// Mỗi lần chạm mới của một cản: giá bật lại được bao xa trước khi bị phá (nến M5 đóng qua mép xa) hoặc hết 240 phút.
// Chỉ tính trên giá và nến do bên gọi đưa vào; không đọc MT5, không gửi lệnh.
#ifndef SIG_PROBE_MQH
#define SIG_PROBE_MQH

#include <Generic\HashMap.mqh>
#include "SigDetect.mqh"

#define SIG_PROBE_MIN 240              // theo dõi tối đa (phút)
#define SIG_PROBE_CAP 10.0             // chặn trên khi lấy trung bình (ATR M5)
const double SIG_PROBE_K[3] = {1.0, 2.0, 4.0}; // ngưỡng bật lại (ATR M5)

struct SigProbe
  {
   SigTouch          t;
   double            atr5;      // ATR M5 lúc chạm
   double            best;      // quãng bật xa nhất khỏi mép gần theo chiều cản (giá)
  };

struct SigProbeAcc
  {
   string            key;
   int               n[2];      // 0 thật, 1 giả
   int               hit[2][3]; // bật >= 1/2/4 ATR M5 trước khi bị phá
   int               brk[2];    // bị phá trong thời gian theo dõi
   double            sum5[2];   // tổng quãng bật (ATR M5, chặn trên)
   double            sums[2];   // tổng quãng bật (ATR khung cản)
   int               ns[2];
  };

class SigProbeBook
  {
private:
   SigProbe          m_p[];     // đã qua nến M1 lúc chạm: cập nhật bằng đỉnh/đáy nến M1
   int               m_n;
   SigProbe          m_w[];     // còn trong nến M1 lúc chạm: cập nhật theo tick (đỉnh/đáy nến đó có phần trước lúc chạm)
   int               m_wn;
   SigProbeAcc       m_a[];
   int               m_an;
   CHashMap<string,int> m_slot;
   int               m_raw;     // file ghi từng lần chạm; INVALID_HANDLE thì không ghi
   int               m_done;

   int               Slot(const string key)
     {
      int i;
      if(m_slot.TryGetValue(key,i)) return i;
      m_slot.Add(key,m_an);
      ArrayResize(m_a,m_an+1,64);
      ZeroMemory(m_a[m_an]);
      m_a[m_an].key=key;
      m_an++;
      return m_an-1;
     }

   void              Add(const string key, const SigProbe &p, bool broken)
     {
      int s=Slot(key), k=p.t.fake ? 1 : 0;
      double b5=(p.atr5>0) ? p.best/p.atr5 : 0;
      m_a[s].n[k]++;
      for(int j=0;j<3;j++) if(b5>=SIG_PROBE_K[j]) m_a[s].hit[k][j]++;
      if(broken) m_a[s].brk[k]++;
      m_a[s].sum5[k]+=MathMin(b5,SIG_PROBE_CAP);
      if(p.t.atr_src>0) { m_a[s].sums[k]+=p.best/p.t.atr_src; m_a[s].ns[k]++; }
     }

   void              Record(const SigProbe &p, bool broken, datetime when)
     {
      string lc=(p.t.test_no==0) ? "1" : (p.t.test_no==1 ? "2" : "3+");
      Add("tat_ca",p,broken);
      Add("nhom_can="+SigGroupName(p.t.group),p,broken);
      Add("loai_can="+SigTypeName(p.t.type),p,broken);
      Add("doi_vai="+(p.t.flip>0?"da_doi_vai":"goc"),p,broken);
      Add("lan_cham="+lc,p,broken);
      Add("so_can_trung="+SigConfBucket(p.t.conf),p,broken);
      Add("luc_bat="+SigDispBucket(p.t.disp),p,broken);
      Add("than_dong_luc="+SigBodyBucket(p.t.body_max),p,broken);
      Add("pha_cau_truc="+SigBosBucket(p.t.bos),p,broken);
      Add("do_lon_dinh="+SigRankBucket(p.t.rank),p,broken);
      Add("tinh_chinh="+SigRefName(p.t.ref_tf),p,broken);
      Add("nhom_can="+SigGroupName(p.t.group)+" tinh_chinh="+SigRefName(p.t.ref_tf),p,broken);
      if(p.t.flip>0) Add("nen_pha="+SigBodyBucket(p.t.brk_body),p,broken);
      if(m_raw!=INVALID_HANDLE)
         FileWriteString(m_raw,IntegerToString(p.t.level_id)+";"+(p.t.fake?"gia":"that")+";"+
                         TimeToString(p.t.time,TIME_DATE|TIME_SECONDS)+";"+(p.t.dir>0?"ho_tro":"khang_cu")+";"+
                         SigGroupName(p.t.group)+";"+SigTypeName(p.t.type)+";"+IntegerToString(p.t.flip)+";"+lc+";"+
                         IntegerToString(p.t.conf)+";"+DoubleToString(p.t.disp,2)+";"+DoubleToString(p.t.body_max,2)+";"+
                         IntegerToString(p.t.bos)+";"+IntegerToString(p.t.rank)+";"+DoubleToString(p.t.brk_body,2)+";"+
                         DoubleToString(p.atr5,3)+";"+DoubleToString(p.best,3)+";"+(broken?"1":"0")+";"+
                         IntegerToString((int)((when-p.t.time)/60))+";"+SigRefName(p.t.ref_tf)+";"+
                         DoubleToString(MathAbs(p.t.far-p.t.near),3)+"\r\n");
      m_done++;
     }

   void              Finish(int i, bool broken, datetime when)
     {
      Record(m_p[i],broken,when);
      m_p[i]=m_p[m_n-1];
      m_n--;
     }

   void              FinishWarm(int i, bool broken, datetime when)
     {
      Record(m_w[i],broken,when);
      m_w[i]=m_w[m_wn-1];
      m_wn--;
     }

   static string     F(double v, int d) { return DoubleToString(v,d); }
   static string     Pct(int a, int n) { return n>0 ? DoubleToString(100.0*a/n,1) : "-"; }

public:
                     SigProbeBook() { m_raw=INVALID_HANDLE; Init(); }

   void              Init()
     {
      m_n=0; m_wn=0; m_an=0; m_done=0;
      ArrayResize(m_p,0,256); ArrayResize(m_w,0,64); ArrayResize(m_a,0,64);
      m_slot.Clear();
     }

   void              SetRaw(int fh)
     {
      m_raw=fh;
      if(fh!=INVALID_HANDLE)
         FileWriteString(fh,"id_can;that_gia;gio_cham;vai_tro;nhom;loai;doi_vai;lan_cham;so_can_trung;luc_bat_ATR;than_dong_luc_ATR;"
                         "pha_cau_truc;do_lon_dinh;than_nen_pha_ATR;atr_M5;bat_gia;bi_pha;phut;tinh_chinh;be_rong_vung\r\n");
     }

   bool              Acc(const string key, SigProbeAcc &out)
     {
      int i;
      if(!m_slot.TryGetValue(key,i)) return false;
      out=m_a[i];
      return true;
     }
   int               OpenCount() { return m_n+m_wn; }
   int               DoneCount() { return m_done; }

   void              Open(const SigTouch &t, double bid, double atr5)
     {
      if(m_wn>=ArraySize(m_w)) ArrayResize(m_w,m_wn+64);
      SigProbe p;
      ZeroMemory(p);
      p.t=t; p.atr5=atr5;
      p.best=MathMax(0.0,t.dir*(bid-t.near));
      m_w[m_wn++]=p;
     }

   // Báo giá: chỉ cập nhật các lần chạm còn trong nến M1 lúc chạm.
   void              OnTick(double bid)
     {
      for(int i=0;i<m_wn;i++) m_w[i].best=MathMax(m_w[i].best,m_w[i].t.dir*(bid-m_w[i].t.near));
     }

   // Nến M1 đóng: lần chạm cũ lấy đỉnh/đáy cả nến; lần chạm mới thôi theo tick từ nến sau. Hết giờ theo dõi thì kết thúc.
   void              OnM1Close(const ScpBar &bar)
     {
      for(int i=m_n-1;i>=0;i--)
        {
         double ext=(m_p[i].t.dir>0) ? bar.h : bar.l;
         m_p[i].best=MathMax(m_p[i].best,m_p[i].t.dir*(ext-m_p[i].t.near));
         if(bar.close_time-m_p[i].t.time>=SIG_PROBE_MIN*60) Finish(i,false,bar.close_time);
        }
      for(int i=m_wn-1;i>=0;i--)
        {
         if(bar.close_time<=m_w[i].t.time) continue;
         if(m_n>=ArraySize(m_p)) ArrayResize(m_p,m_n+256);
         m_p[m_n++]=m_w[i];
         m_w[i]=m_w[m_wn-1];
         m_wn--;
        }
     }

   // Nến M5 đóng qua mép xa thêm eps sau lúc chạm: cản bị phá, kết thúc lần đo.
   void              OnM5Close(const ScpBar &bar, double eps_m5)
     {
      for(int i=m_n-1;i>=0;i--)
        {
         if(bar.close_time<=m_p[i].t.time) continue;
         bool broken=(m_p[i].t.dir>0 && bar.c<m_p[i].t.far-eps_m5) || (m_p[i].t.dir<0 && bar.c>m_p[i].t.far+eps_m5);
         if(broken) Finish(i,true,bar.close_time);
        }
      for(int i=m_wn-1;i>=0;i--)
        {
         if(bar.close_time<=m_w[i].t.time) continue;
         bool broken=(m_w[i].t.dir>0 && bar.c<m_w[i].t.far-eps_m5) || (m_w[i].t.dir<0 && bar.c>m_w[i].t.far+eps_m5);
         if(broken) FinishWarm(i,true,bar.close_time);
        }
     }

   void              CloseAll(datetime now)
     {
      for(int i=m_n-1;i>=0;i--) Finish(i,false,now);
      for(int i=m_wn-1;i>=0;i--) FinishWarm(i,false,now);
     }

   void              Write(int fh, const string header)
     {
      FileWriteString(fh,header);
      FileWriteString(fh,"\r\nPhản ứng tại cản (SPEC 24.3): mỗi lần chạm mới của một cản, giá bật lại bao xa khỏi mép gần trước khi"
                      " nến M5 đóng qua mép xa (bị phá) hoặc hết "+IntegerToString(SIG_PROBE_MIN)+" phút. Không phụ thuộc cách vào lệnh.\r\n");
      FileWriteString(fh,"bat>=kATR = % lần chạm bật được ít nhất k ATR M5 trước khi bị phá; bi_pha = % bị phá trong thời gian theo dõi;"
                      " bat_TB = trung bình (ATR M5, chặn "+F(SIG_PROBE_CAP,0)+"); gia = cản giả cùng đặc điểm.\r\n\r\n");
      FileWriteString(fh,"nhom;n_that;bat>=1ATR%;bat>=2ATR%;bat>=4ATR%;bi_pha%;bat_TB_ATR_M5;bat_TB_ATR_khung_can;"
                      "n_gia;bat>=1ATR%_gia;bat>=2ATR%_gia;bat>=4ATR%_gia;bi_pha%_gia;bat_TB_ATR_M5_gia;that-gia(bat>=2ATR)\r\n");
      for(int i=0;i<m_an;i++)
        {
         string row=m_a[i].key;
         for(int k=0;k<2;k++)
           {
            int n=m_a[i].n[k];
            row+=";"+IntegerToString(n);
            for(int j=0;j<3;j++) row+=";"+Pct(m_a[i].hit[k][j],n);
            row+=";"+Pct(m_a[i].brk[k],n)+";"+(n>0?F(m_a[i].sum5[k]/n,2):"-");
            if(k==0) row+=";"+(m_a[i].ns[0]>0?F(m_a[i].sums[0]/m_a[i].ns[0],2):"-");
           }
         bool both=(m_a[i].n[0]>0 && m_a[i].n[1]>0);
         row+=";"+(both?F(100.0*m_a[i].hit[0][1]/m_a[i].n[0]-100.0*m_a[i].hit[1][1]/m_a[i].n[1],1):"-");
         FileWriteString(fh,row+"\r\n");
        }
     }
  };

#endif // SIG_PROBE_MQH
