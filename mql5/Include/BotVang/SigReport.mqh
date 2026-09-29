// SigReport.mqh — tổng kết công cụ đo tín hiệu: so tín hiệu thật với đối chứng theo từng nhóm (SPEC mục 22.3).
// Chỉ đọc bản ghi đã xong và ghi file; không gửi lệnh.
#ifndef SIG_REPORT_MQH
#define SIG_REPORT_MQH

#include <Generic\HashMap.mqh>
#include "SigTrack.mqh"
#include "SigLevels.mqh"

#define SIG_NM (SIG_NR+SIG_NS)   // số cách tính R: 6 cuộc đua + 6 cách chốt hai phần

struct SigAcc
  {
   string            key;
   int               n[4];               // theo loại bản ghi SIG/REV/RT/FAKE
   int               win1[4];            // thắng cuộc đua 1R:1R
   double            sum[4][SIG_NM], sq[4][SIG_NM];
   int               cnt[4][SIG_NM];     // số bản ghi áp dụng được cho cách tính đó
   double            pct[SIG_NM];        // tổng R × % vốn theo bậc (chỉ tín hiệu thật)
  };

string SigMetricName(int m)
  {
   if(m<SIG_NR)
     {
      string r[SIG_NR]={"dua_1R","dua_1.5R","dua_2R","dua_3R","dua_can_lon","dua_DOL"};
      return r[m];
     }
   string s[SIG_NS]={"hai_phan_1R+can_lon","hai_phan_1.5R+can_lon","hai_phan_canM5+can_lon",
                     "hai_phan_1R+DOL","hai_phan_1.5R+DOL","hai_phan_canM5+DOL"};
   return s[m-SIG_NR];
  }

string SigSlName(int v) { return v==0 ? "sat_rau" : (v==1 ? "rau+0.3ATR" : "rau+0.5ATR"); }
string SigVariantName(int moc, int sl, bool wick)
  {
   string m=!wick ? "moc=mep_gan" : (moc==0 ? "moc=than" : (moc==1 ? "moc=giua_rau" : "moc=dinh_day_rau"));
   return m+" dung="+SigSlName(sl);
  }

string SigReactionName(int r) { return r==1 ? "P1_rut_rau" : (r==2 ? "P2_nhan_chim" : (r==3 ? "P3_pha_dinh_day_nho" : "cho_giay")); }

class SigReport
  {
private:
   SigAcc            m_a[];
   int               m_n;
   double            m_slip;          // đệm trượt mỗi chặng (giá)

   CHashMap<string,int> m_slot;       // khóa nhóm → chỉ số: lượt dài có hàng trăm nghìn nhóm

   int               Slot(const string key)
     {
      int i;
      if(m_slot.TryGetValue(key,i)) return i;
      m_slot.Add(key,m_n);
      ArrayResize(m_a,m_n+1,64);
      ZeroMemory(m_a[m_n]);
      m_a[m_n].key=key;
      m_n++;
      return m_n-1;
     }

   void              Add(const string key, const SigRec &x, bool with_slip)
     {
      int s=Slot(key), k=x.kind;
      double slip_r=with_slip ? 2.0*m_slip/x.r : 0.0;
      m_a[s].n[k]++;
      if(x.rs[0]==SIG_WIN) m_a[s].win1[k]++;
      for(int m=0;m<SIG_NM;m++)
        {
         int st=(m<SIG_NR) ? x.rs[m] : x.ss[m-SIG_NR];
         if(st==SIG_NA) continue;
         double v=((m<SIG_NR) ? x.rr[m] : x.sr[m-SIG_NR])-slip_r;
         m_a[s].sum[k][m]+=v; m_a[s].sq[k][m]+=v*v; m_a[s].cnt[k][m]++;
         if(k==SIG_K_SIG) m_a[s].pct[m]+=v*SIG_TIER_RISK[MathMax(0,MathMin(4,x.f.tier))];
        }
     }

   static string     F(double v, int d) { return DoubleToString(v,d); }

   // Trung bình và nửa khoảng tin cậy 95% (bỏ qua chồng lấn giữa các bản ghi: khoảng thật rộng hơn).
   void              Mean(const SigAcc &a, int k, int m, double &mean, double &half)
     {
      int c=a.cnt[k][m];
      mean=0; half=0;
      if(c<=0) return;
      mean=a.sum[k][m]/c;
      if(c<2) return;
      double var=(a.sq[k][m]-c*mean*mean)/(c-1);
      half=1.96*MathSqrt(MathMax(var,0)/c);
     }

public:
   void              Init(double slip_per_leg) { m_n=0; m_slip=slip_per_leg; ArrayResize(m_a,0,64); m_slot.Clear(); }

   // Chia một bản ghi vào các nhóm, tách theo biến thể (kiểu mốc, kiểu dừng).
   // Tín hiệu gần tin tách riêng, không vào số chính (né tin, SPEC 22.1).
   void              Classify(const SigRec &x, bool with_slip)
     {
      const SigFeatures f=x.f;
      // Mỗi định nghĩa "phá" (a: thân đóng qua; b: râu vượt) cho một tập tín hiệu hợp lệ riêng (SPEC 23.2).
      for(int d=0;d<2;d++)
        {
         bool ok=(f.scen==1) ? (d==0 || !f.wick_broken) : ((f.flip_def & (d==0 ? 1 : 2))!=0);
         if(!ok) continue;
         string sc=(f.scen==1) ? "K1" : (f.scen==5 ? "K5" : "K2");
         if(f.scen!=1 && f.test_no>0) sc=sc+"_lan_sau";
         string v=(f.entry_mode==1?"CHO_GIAY ":"")+sc+" pha="+(d==0?"than":"rau")+" "+SigVariantName(f.var_moc,f.var_sl,f.wick)+" | ";
         if(f.news==1) { Add(v+"tin=gan_tin (khong vao so chinh)",x,with_slip); continue; }
         Add(v+"tat_ca",x,with_slip);
         Add(v+"nhom_can="+SigGroupName(f.group),x,with_slip);
         Add(v+"loai_can="+SigTypeName(f.ltype),x,with_slip);
         Add(v+"bac="+IntegerToString(f.tier),x,with_slip);
         Add(v+"trung_can="+(f.conf>=1?"co":"khong"),x,with_slip);
         if(f.entry_mode==0) Add(v+"phan_ung="+SigReactionName(f.reaction),x,with_slip);
         if(f.entry_mode==0 && f.reaction<3) Add(v+"phan_ung_dong_vuot_mep_gan="+(f.strict?"co":"khong"),x,with_slip);
         Add(v+"khung_vao="+(f.etf==0?"M1":"M5"),x,with_slip);
         Add(v+"lan_cham="+(f.test_no==0?"1":(f.test_no==1?"2":"3+")),x,with_slip);
         Add(v+"gio="+StringFormat("%02d",f.hour),x,with_slip);
         Add(v+"chi_phi_tren_R="+(f.cost_r<=0.05?"<=5%":(f.cost_r<=0.10?"5-10%":">10%")),x,with_slip);
         if(f.news==-1) Add(v+"tin=thieu_lich",x,with_slip);
         // Luật đề xuất của chủ bot cho K1: lần đầu mốc đỉnh/đáy râu; lần sau mốc giữa râu (hoặc đỉnh/đáy râu).
         if(f.entry_mode==0 && f.scen==1 && f.wick && ((f.test_no==0 && f.var_moc==2) || (f.test_no>0 && f.var_moc==1)))
            Add("K1 pha="+(d==0?"than":"rau")+" LUAT_CHU_BOT dau=dinh_rau,sau=giua_rau dung="+SigSlName(f.var_sl)+" | tat_ca",x,with_slip);
        }
     }

   // Bảng ngắn: mỗi biến thể một dòng cho các cách tính chính.
   void              WriteSummary(int fh)
     {
      FileWriteString(fh,"\r\n=== TÓM TẮT THEO BIẾN THỂ (tín hiệu xa tin) ===\r\n");
      FileWriteString(fh,"bien_the;n_that;thang_1R%;R_dua_1R;R_ngau_nhien_1R;R_can_gia_1R;R_hai_phan_1R+can_lon;R_hai_phan_1R+DOL;that-ngau_nhien(1R);that-can_gia(1R)\r\n");
      for(int i=0;i<m_n;i++)
        {
         if(StringFind(m_a[i].key,"| tat_ca")<0) continue;
         double ms,hs,mt,ht,mf,hf,s1,h1,s2,h2;
         Mean(m_a[i],SIG_K_SIG,0,ms,hs);
         Mean(m_a[i],SIG_K_RT,0,mt,ht);
         Mean(m_a[i],SIG_K_FAKE,0,mf,hf);
         Mean(m_a[i],SIG_K_SIG,SIG_NR+0,s1,h1);
         Mean(m_a[i],SIG_K_SIG,SIG_NR+3,s2,h2);
         double win=(m_a[i].n[SIG_K_SIG]>0) ? 100.0*m_a[i].win1[SIG_K_SIG]/m_a[i].n[SIG_K_SIG] : 0;
         FileWriteString(fh,m_a[i].key+";"+IntegerToString(m_a[i].n[SIG_K_SIG])+";"+F(win,1)+";"+F(ms,3)+"±"+F(hs,3)+";"+
                         F(mt,3)+";"+F(mf,3)+";"+F(s1,3)+";"+F(s2,3)+";"+
                         (m_a[i].cnt[SIG_K_RT][0]>0?F(ms-mt,3):"-")+";"+(m_a[i].cnt[SIG_K_FAKE][0]>0?F(ms-mf,3):"-")+"\r\n");
        }
     }

   void              Write(int fh, int total_real, int total_fake, const string header)
     {
      FileWriteString(fh,header);
      FileWriteString(fh,"\r\nCách đọc: R sau spread (mua thoát Bid, bán thoát Ask) và sau đệm trượt đã khai báo; thang = 1 lần khoảng dừng.\r\n");
      FileWriteString(fh,"that = tín hiệu thật; nguoc = đánh ngược cùng lúc; ngau_nhien = cùng giờ ngày khác; can_gia = cản giả cùng khung/loại.\r\n");
      FileWriteString(fh,"Khoảng ±95% coi các bản ghi độc lập; tín hiệu chồng thời gian nên khoảng thật rộng hơn. Đây là số đo trên giấy, không phải tiền EA.\r\n");
      FileWriteString(fh,"Tín hiệu thật: "+IntegerToString(total_real)+" | tín hiệu từ cản giả: "+IntegerToString(total_fake)+"\r\n\r\n");
      FileWriteString(fh,"nhom;cach_tinh;n_that;thang_1R_that%;R_TB_that;+-95%;R_TB_nguoc;R_TB_ngau_nhien;n_can_gia;R_TB_can_gia;that-ngau_nhien;that-can_gia;tong_R_x_%von\r\n");
      for(int i=0;i<m_n;i++)
         for(int m=0;m<SIG_NM;m++)
           {
            if(m_a[i].cnt[SIG_K_SIG][m]==0 && m_a[i].cnt[SIG_K_FAKE][m]==0) continue;
            double ms,hs,mr,hr,mt,ht,mf,hf;
            Mean(m_a[i],SIG_K_SIG,m,ms,hs);
            Mean(m_a[i],SIG_K_REV,m,mr,hr);
            Mean(m_a[i],SIG_K_RT,m,mt,ht);
            Mean(m_a[i],SIG_K_FAKE,m,mf,hf);
            double win=(m_a[i].n[SIG_K_SIG]>0) ? 100.0*m_a[i].win1[SIG_K_SIG]/m_a[i].n[SIG_K_SIG] : 0;
            FileWriteString(fh,m_a[i].key+";"+SigMetricName(m)+";"+IntegerToString(m_a[i].cnt[SIG_K_SIG][m])+";"+
                            F(win,1)+";"+F(ms,3)+";"+F(hs,3)+";"+F(mr,3)+";"+F(mt,3)+";"+
                            IntegerToString(m_a[i].cnt[SIG_K_FAKE][m])+";"+F(mf,3)+";"+
                            (m_a[i].cnt[SIG_K_RT][m]>0?F(ms-mt,3):"-")+";"+(m_a[i].cnt[SIG_K_FAKE][m]>0?F(ms-mf,3):"-")+";"+
                            F(m_a[i].pct[m],2)+"\r\n");
           }
     }
  };

#endif // SIG_REPORT_MQH
