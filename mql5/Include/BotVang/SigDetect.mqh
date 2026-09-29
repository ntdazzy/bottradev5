// SigDetect.mqh — phát hiện chạm cản, phá trong một nhịp và phản ứng P1/P2/P3 cho công cụ đo (SPEC mục 22.1–22.4).
// Nhận giá và nến đã đóng do bên gọi đưa vào; không đọc MT5, không gửi lệnh.
#ifndef SIG_DETECT_MQH
#define SIG_DETECT_MQH

#include "ScpTypes.mqh"
#include "ScpSeries.mqh"
#include "ScpReaction.mqh"
#include "SigLevels.mqh"

struct SigEpisode
  {
   long              level_id;
   long              level_parent;
   int               etf;
   int               var;          // kiểu mốc chạm: 0 mép gần/thân, 1 giữa râu, 2 đỉnh/đáy râu (SPEC 22.4)
   int               dir;          // +1 mua ở hỗ trợ, -1 bán ở kháng cự
   datetime          touch_time;
   double            lo, hi;       // dải cản đóng băng lúc chạm
   double            near, far;    // mép gần và mép xa (đỉnh/đáy râu) theo chiều tiếp cận
   double            trig;         // mức tính là chạm theo kiểu mốc
   double            eps, atr, small, ext;
   int               bars;
   int               tier, conf, group, type, test_no;
   bool              fake, minor, wick;
   int               flip, flip_def;
   bool              wick_broken, cont;
   bool              limit_done;   // lệnh chờ trên giấy tại mốc đã khớp (chỉ để so sánh, SPEC 23.1)
   int               ltier;        // bậc cản trước khi xét trùng cản
   double            disp, body_max, brk_body;
   int               bos, rank;
  };

struct SigSignal
  {
   long              level_id;
   long              level_parent;
   int               etf;
   int               var;
   int               dir;
   datetime          bar_close;
   double            bar_c;
   double            ext, far, eps, atr;
   int               reaction;     // 0 = lệnh chờ trên giấy khớp tại mốc (không chờ phản ứng)
   bool              strict;
   int               bars_after;
   int               tier, conf, group, type, test_no;
   bool              fake, minor, wick;
   int               flip, flip_def;
   bool              wick_broken, cont;
   double            lo, hi;       // dải cản lúc chạm (gộp tín hiệu trùng)
   int               ltier;
   double            disp, body_max, brk_body;
   int               bos, rank;
   int               merged;       // số tín hiệu cùng lúc ở cản chồng lên bị gộp vào tín hiệu này (SPEC 24.2)
  };

// Lần chạm mới của một cản (mọi khung vào/kiểu mốc dùng chung): dùng đo phản ứng tại cản, không phụ thuộc cách vào (SPEC 24.3).
struct SigTouch
  {
   long              level_id;
   datetime          time;
   int               dir;
   double            near, far, eps;
   int               group, type, flip, test_no, conf, ltier;
   bool              fake;
   double            atr_src, disp, body_max, brk_body;
   int               bos, rank;
  };

class SigDetector
  {
private:
   SigEpisode        m_ep[];
   int               m_n;
   SigSignal         m_out[];
   int               m_out_n;
   SigTouch          m_tch[];
   int               m_tch_n;
   int               m_merged;
   int               m_react_bars;
   int               m_touch, m_broken, m_expired, m_reacted, m_minor_rejected, m_limit;

   void              End(int k, SigLevelBook &book)
     {
      int idx=book.IndexOf(m_ep[k].level_id);
      if(idx>=0) book.SetEpOpen(idx,m_ep[k].etf,m_ep[k].var,false);
      m_ep[k]=m_ep[m_n-1];
      m_n--;
     }

   // Cản tạm M5: cấu trúc M5 cùng chiều và nhịp hồi hiện tại không quá 50% nhịp đẩy trước (SPEC 22.2).
   bool              MinorOk(ScpSeries *m5, int dir, double bid)
     {
      if(m5==NULL || m5.Dir()!=(dir>0 ? SCP_DIR_UP : SCP_DIR_DOWN)) return false;
      int last=-1, prev=-1;
      for(int i=m5.PivotCount()-1;i>=0;i--)
        {
         ScpPivot p=m5.Pivot(i);
         if(!p.ambiguous && p.is_high==(dir>0)) { last=i; break; }
        }
      if(last<0) return false;
      for(int i=last-1;i>=0;i--)
        {
         ScpPivot p=m5.Pivot(i);
         if(!p.ambiguous && p.is_high==(dir<0)) { prev=i; break; }
        }
      if(prev<0) return false;
      double endp=m5.Pivot(last).price, startp=m5.Pivot(prev).price;
      double leg=dir*(endp-startp);
      double pull=dir*(endp-bid);
      return leg>0 && pull>=0 && pull<=0.5*leg;
     }

   void              Emit(int k, int re, bool strict, datetime when, double close_ref, SigLevelBook &book)
     {
      if(m_out_n>=ArraySize(m_out)) ArrayResize(m_out,m_out_n+64);
      SigSignal g;
      ZeroMemory(g);
      g.level_id=m_ep[k].level_id; g.level_parent=m_ep[k].level_parent;
      g.etf=m_ep[k].etf; g.var=m_ep[k].var; g.dir=m_ep[k].dir; g.bar_close=when; g.bar_c=close_ref;
      g.ext=m_ep[k].ext; g.far=m_ep[k].far; g.eps=m_ep[k].eps; g.atr=m_ep[k].atr;
      g.reaction=re; g.strict=strict; g.bars_after=m_ep[k].bars;
      g.tier=m_ep[k].tier; g.conf=m_ep[k].conf; g.group=m_ep[k].group; g.type=m_ep[k].type;
      g.test_no=m_ep[k].test_no; g.fake=m_ep[k].fake; g.minor=m_ep[k].minor; g.wick=m_ep[k].wick;
      g.flip=m_ep[k].flip; g.flip_def=m_ep[k].flip_def; g.cont=m_ep[k].cont;
      g.lo=m_ep[k].lo; g.hi=m_ep[k].hi; g.ltier=m_ep[k].ltier;
      g.disp=m_ep[k].disp; g.body_max=m_ep[k].body_max; g.brk_body=m_ep[k].brk_body; g.bos=m_ep[k].bos; g.rank=m_ep[k].rank;
      int li=book.IndexOf(m_ep[k].level_id);
      SigLevel cur;
      g.wick_broken=(li>=0 && book.Get(li,cur)) ? cur.wick_broken : m_ep[k].wick_broken;
      m_out[m_out_n++]=g;
     }

public:
                     SigDetector() { Init(3); }

   void              Init(int react_bars)
     {
      m_n=0; m_out_n=0; m_react_bars=react_bars;
      m_touch=0; m_broken=0; m_expired=0; m_reacted=0; m_minor_rejected=0; m_limit=0;
      m_tch_n=0; m_merged=0;
      ArrayResize(m_ep,0,256); ArrayResize(m_out,0,64); ArrayResize(m_tch,0,64);
     }

   int               Touches() { return m_touch; }
   int               BrokenInSwing() { return m_broken; }
   int               Expired() { return m_expired; }
   int               Reacted() { return m_reacted; }
   int               MinorRejected() { return m_minor_rejected; }
   int               LimitFills() { return m_limit; }
   int               Merged() { return m_merged; }
   int               ActiveCount() { return m_n; }

   // Mỗi báo giá: mở lần chạm mới trên các cản gần, cập nhật cực trị các lần chạm đang mở.
   void              OnTick(SigLevelBook &book, const int &near[], int near_n, double bid, datetime now,
                            ScpSeries *m1, ScpSeries *m5, double tick, bool use_minor, bool use_m1, bool use_m5)
     {
      for(int k=0;k<m_n;k++)
        {
         if(m_ep[k].dir>0 && bid<m_ep[k].ext) m_ep[k].ext=bid;
         if(m_ep[k].dir<0 && bid>m_ep[k].ext) m_ep[k].ext=bid;
         // Lệnh chờ trên giấy tại mốc: khớp khi Bid chạm đúng mốc; hết khi lần chạm kết thúc (phản ứng, hết hạn, bị phá).
         if(!m_ep[k].limit_done && ((m_ep[k].dir>0 && bid<=m_ep[k].trig) || (m_ep[k].dir<0 && bid>=m_ep[k].trig)))
           {
            m_ep[k].limit_done=true;
            Emit(k,SCP_RE_NONE,false,now,bid,book);
            m_limit++;
           }
        }
      for(int q=0;q<near_n;q++)
        {
         int idx=near[q];
         book.MarkSweep(idx,bid);
         SigLevel lv;
         if(!book.Get(idx,lv) || !book.Usable(idx,now)) continue;
         for(int etf=0;etf<2;etf++)
           {
            if((etf==0 && !use_m1) || (etf==1 && !use_m5)) continue;
            ScpSeries *s=(etf==0) ? m1 : m5;
            if(s==NULL || !s.Info().data_ok) continue;
            double eps=MathMax(2.0*tick,SCP_K_BUFFER*s.Atr());
            int nvar=lv.wick ? 3 : 1;
            for(int v=0;v<nvar;v++)
              {
               if(book.EpOpen(idx,etf,v)) continue;
               int side=book.ArmSide(idx,etf,v);
               if(side==0 || (lv.role!=0 && side!=lv.role)) continue;
               double nearp=(side>0) ? lv.top : lv.bottom;
               double farp=(side>0) ? lv.bottom : lv.top;
               // Mốc chạm: mức thân (Classic/Gap) hoặc mép gần; với cản có râu thêm giữa râu và đỉnh/đáy râu.
               double trig=(v==0) ? (lv.lvl>0 ? lv.lvl : nearp) : (v==1 ? (lv.bottom+lv.top)*0.5 : farp);
               bool touch=(side>0 && bid<=trig+eps) || (side<0 && bid>=trig-eps);
               if(!touch) continue;
               book.SetArm(idx,etf,v,0); // mở lại cần một nến khung vào đóng hoàn toàn ngoài dải
               bool minor=(lv.group==SIG_G_M5TAM);
               if(minor && (!use_minor || !MinorOk(m5,side,bid))) { m_minor_rejected++; continue; }
               bool new_test=!book.AnyOpen(idx);
               int test_no=book.BeginTest(idx);
               if(m_n>=ArraySize(m_ep)) ArrayResize(m_ep,m_n+256);
               SigEpisode e;
               ZeroMemory(e);
               e.level_id=lv.id; e.level_parent=lv.parent; e.etf=etf; e.var=v; e.dir=side;
               e.touch_time=now; e.lo=lv.bottom; e.hi=lv.top;
               e.near=nearp; e.far=farp; e.trig=trig;
               e.eps=eps; e.atr=s.Atr(); e.ext=bid; e.bars=0;
               // P3: đỉnh (mua) / đáy (bán) nhỏ của nhịp đi vào, đã biết trước lúc chạm, trong 20 nến.
               e.small=s.SmallPivot(side>0,s.Count(),20,now);
               e.conf=book.Confluence(idx,eps,now);
               e.tier=(e.conf>=1) ? 4 : lv.tier;
               e.group=lv.group; e.type=lv.type; e.test_no=test_no;
               e.fake=lv.fake; e.minor=minor; e.wick=lv.wick;
               e.flip=lv.flip; e.flip_def=lv.flip_def; e.wick_broken=lv.wick_broken; e.cont=lv.cont;
               e.ltier=lv.tier; e.disp=lv.disp; e.body_max=lv.body_max; e.brk_body=lv.brk_body; e.bos=lv.bos; e.rank=lv.rank;
               m_ep[m_n++]=e;
               if(new_test)
                 {
                  if(m_tch_n>=ArraySize(m_tch)) ArrayResize(m_tch,m_tch_n+64);
                  SigTouch t;
                  ZeroMemory(t);
                  t.level_id=lv.id; t.time=now; t.dir=side; t.near=nearp; t.far=farp; t.eps=eps;
                  t.group=lv.group; t.type=lv.type; t.flip=lv.flip; t.test_no=test_no; t.conf=e.conf; t.ltier=lv.tier;
                  t.fake=lv.fake; t.atr_src=lv.atr_src; t.disp=lv.disp; t.body_max=lv.body_max; t.brk_body=lv.brk_body;
                  t.bos=lv.bos; t.rank=lv.rank;
                  m_tch[m_tch_n++]=t;
                 }
               book.SetEpOpen(idx,etf,v,true);
               m_touch++;
               if((side>0 && bid<=trig) || (side<0 && bid>=trig))
                 { m_ep[m_n-1].limit_done=true; Emit(m_n-1,SCP_RE_NONE,false,now,bid,book); m_limit++; }
              }
           }
        }
     }

   // Nến M5 đóng vượt mép xa thêm eps sau lúc chạm: cản bị phá trong một nhịp, hủy lần chạm (cả M1 và M5).
   void              OnM5Close(const ScpBar &bar, double eps_m5, SigLevelBook &book)
     {
      for(int k=m_n-1;k>=0;k--)
        {
         if(bar.close_time<=m_ep[k].touch_time) continue;
         bool broken=(m_ep[k].dir>0 && bar.c<m_ep[k].far-eps_m5) || (m_ep[k].dir<0 && bar.c>m_ep[k].far+eps_m5);
         if(!broken) continue;
         m_broken++;
         End(k,book);
        }
     }

   // Nến khung vào vừa đóng: cập nhật trạng thái rời dải của cản gần, xét phản ứng các lần chạm đang mở.
   void              OnEntryBarClosed(int etf, ScpSeries *s, SigLevelBook &book, const int &near[], int near_n,
                                      double tick)
     {
      if(s==NULL || s.Count()<3) return;
      ScpBar bar=s.LastBar(), prev=s.Bar(s.Count()-2);
      double eps_now=MathMax(2.0*tick,SCP_K_BUFFER*s.Atr());
      for(int q=0;q<near_n;q++)
        {
         int idx=near[q];
         SigLevel lv;
         if(!book.Get(idx,lv)) continue;
         int side=(bar.l>lv.top+eps_now) ? 1 : (bar.h<lv.bottom-eps_now ? -1 : 0);
         if(side==0) continue;
         for(int v=0;v<3;v++) if(!book.EpOpen(idx,etf,v)) book.SetArm(idx,etf,v,side);
        }
      for(int k=m_n-1;k>=0;k--)
        {
         if(m_ep[k].etf!=etf || bar.close_time<=m_ep[k].touch_time) continue;
         m_ep[k].bars++;
         int dir=m_ep[k].dir;
         double eps=m_ep[k].eps, atr=m_ep[k].atr, trig=m_ep[k].trig;
         bool touched=(dir>0) ? (bar.l<=trig+eps) : (bar.h>=trig-eps);
         bool prev_touched=(dir>0) ? (prev.l<=trig+eps) : (prev.h>=trig-eps);
         // Nến phản ứng không được đóng qua mép xa (đã phá cản).
         bool inside=(dir>0) ? (bar.c>=m_ep[k].far-eps) : (bar.c<=m_ep[k].far+eps);
         int re=SCP_RE_NONE;
         bool strict=false;
         if(inside)
           {
            // P1/P2 không bắt đóng vượt mép gần (cản khung lớn có thể rộng); cờ strict ghi điều kiện mục 14.4.
            if(ScpP1(bar,dir,DBL_MAX,-DBL_MAX,atr,touched))
              { re=SCP_RE_P1; strict=ScpP1(bar,dir,m_ep[k].lo,m_ep[k].hi,atr,touched); }
            else if(ScpP2(prev,bar,dir,DBL_MAX,-DBL_MAX,touched || prev_touched))
              { re=SCP_RE_P2; strict=ScpP2(prev,bar,dir,m_ep[k].lo,m_ep[k].hi,touched || prev_touched); }
            else if(ScpP3(bar,dir,m_ep[k].small,eps,true))
               re=SCP_RE_P3;
           }
         if(re!=SCP_RE_NONE)
           {
            Emit(k,re,strict,bar.close_time,bar.c,book);
            m_reacted++;
            End(k,book);
            continue;
           }
         if(m_ep[k].bars>=m_react_bars) { m_expired++; End(k,book); }
        }
     }

   // Tín hiệu a được giữ thay b khi gộp: cản khung lớn hơn, rồi lần chạm sớm hơn, rồi lực bật lớn hơn, rồi mã nhỏ hơn.
   bool              Better(const SigSignal &a, const SigSignal &b)
     {
      if(a.ltier!=b.ltier) return a.ltier>b.ltier;
      if(a.test_no!=b.test_no) return a.test_no<b.test_no;
      if(a.disp!=b.disp) return a.disp>b.disp;
      return a.level_id<b.level_id;
     }

   // Lấy các tín hiệu vừa phát; bên gọi xử lý ngay ở báo giá hiện tại.
   // Tín hiệu vào thị trường phát cùng lúc, cùng chiều/khung vào/kiểu mốc, cùng lớp thật/giả, ở các cản có dải chồng nhau
   // chỉ giữ một (SPEC 24.2). Lệnh chờ trên giấy giữ nguyên từng cản.
   int               Take(SigSignal &out[])
     {
      int n=m_out_n;
      // Xếp từ mạnh tới yếu rồi giữ lần lượt: tín hiệu chồng lên một tín hiệu đã giữ thì gộp vào đó.
      int ord[];
      ArrayResize(ord,n);
      for(int i=0;i<n;i++)
        {
         int p=i;
         while(p>0 && Better(m_out[i],m_out[ord[p-1]])) { ord[p]=ord[p-1]; p--; }
         ord[p]=i;
        }
      int k=0;
      ArrayResize(out,n);
      for(int q=0;q<n;q++)
        {
         SigSignal g=m_out[ord[q]];
         bool merged=false;
         if(g.reaction!=SCP_RE_NONE)
            for(int j=0;j<k && !merged;j++)
              {
               if(out[j].reaction==SCP_RE_NONE || out[j].fake!=g.fake || out[j].dir!=g.dir || out[j].etf!=g.etf ||
                  out[j].var!=g.var || out[j].bar_close!=g.bar_close) continue;
               double e=MathMax(out[j].eps,g.eps);
               if(g.lo-e>out[j].hi+e || out[j].lo-e>g.hi+e) continue;
               out[j].merged++;
               m_merged++;
               merged=true;
              }
         if(!merged) out[k++]=g;
        }
      ArrayResize(out,k);
      m_out_n=0;
      return k;
     }

   // Lấy các lần chạm mới (đo phản ứng tại cản).
   int               TakeTouches(SigTouch &out[])
     {
      int n=m_tch_n;
      ArrayResize(out,n);
      for(int i=0;i<n;i++) out[i]=m_tch[i];
      m_tch_n=0;
      return n;
     }
  };

#endif // SIG_DETECT_MQH
