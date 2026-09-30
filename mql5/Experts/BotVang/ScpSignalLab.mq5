// ScpSignalLab.mq5 — công cụ đo tín hiệu HTF-ZONE (SPEC mục 22.3, 23). CHỈ chạy trong máy thử; không có lệnh gửi.
// Đợt 1: cản L1–L4, L6, DOL; kịch bản K1 (đảo chiều ở cản mới), K2 (phá rồi quay lại, đổi vai), K5 (tiếp diễn).
// Đợt 2: vùng Z của 411 (K2b) và Unicorn (K3) (SPEC 23.6).
// Mỗi tín hiệu được theo dõi trên từng tick thật và so với đánh ngược, vào ngẫu nhiên cùng giờ, cản giả.
// Đo thêm phản ứng tại cản theo sức mạnh cản, tách khỏi cách vào lệnh (SPEC mục 24).
// Kết quả: Common\Files\BotScp\SignalLab\<InpRunName>\ tong_ket.txt, nhom.csv, phan_ung_can.csv, vung_htf.csv
// (tin_hieu.csv và cham_can.csv khi bật InpWriteSignals).
#property strict

#include <BotVang\ScpTypes.mqh>
#include <BotVang\ScpSeries.mqh>
#include <BotVang\ScpSafety.mqh>
#include <BotVang\SigLevels.mqh>
#include <BotVang\SigDetect.mqh>
#include <BotVang\SigTrack.mqh>
#include <BotVang\SigReport.mqh>
#include <BotVang\SigProbe.mqh>
#include <BotVang\SigDraw.mqh>

input string InpRunName      = "lab_run";  // tên lượt đo; không ghi đè lượt đã có
input ulong  InpSeed         = 20260929;   // hạt giống ngẫu nhiên cho đối chứng và cản giả
input bool   InpFakeLevels   = true;       // tạo cản giả đối chứng
input int    InpRandomCopies = 2;          // số lần vào ngẫu nhiên cùng giờ (1–10 ngày sau) mỗi tín hiệu
input int    InpMaxHoldMin   = 480;        // theo dõi tối đa (phút); hết giờ đóng ở giá thoát
input int    InpReactBars    = 3;          // số nến khung vào chờ phản ứng sau chạm
input bool   InpUseM1        = true;       // tìm điểm vào trên M1
input bool   InpUseM5        = true;       // tìm điểm vào trên M5
input bool   InpUseM5Minor   = true;       // cản tạm M5 khi nhịp hồi nông (SPEC 22.2)
input double InpChaseAtr     = 0.25;       // bỏ nếu giá đã chạy quá x ATR khung vào sau nến phản ứng
input double InpSlipPerLeg   = 0.3;        // đệm trượt mỗi chặng (giá) trừ vào kết quả; số nghiên cứu, chưa đo trên demo
input int    InpNewsBeforeMin = 5;         // né tin: phút trước
input int    InpNewsAfterMin  = 5;         // né tin: phút sau
input int    InpWarmupBars   = 800;        // số nến nạp trước mỗi khung
input bool   InpDraw         = true;       // vẽ cản/tín hiệu khi chạy máy thử có hình
input bool   InpWriteSignals = false;      // ghi tin_hieu.csv từng lệnh và cham_can.csv từng lần chạm (rất nặng: ~80 MB mỗi tuần)

const double SIG_SL_EXTRA[3] = {0.0, 0.3, 0.5}; // đệm dừng lỗ thêm theo ATR M5 (SPEC 23.4)

ScpSeries     g_s[SIG_TF_COUNT];
datetime      g_forming[SIG_TF_COUNT];
datetime      g_last_pushed[SIG_TF_COUNT];
long          g_seen[SIG_TF_COUNT];
SigLevelBook  g_book;
SigDetector   g_det;
SigTracker    g_trk;
SigReport     g_rep;
SigProbeBook  g_probe;
datetime      g_news[];
int           g_news_n=0;
int           g_near[];
int           g_near_n=0;
double        g_near_center=0;
string        g_folder;
int           g_fh_levels=INVALID_HANDLE;
int           g_fh_signals=INVALID_HANDLE;
int           g_fh_touches=INVALID_HANDLE;
int           g_limit_records=0;
int           g_signals=0, g_fake_signals=0, g_stale=0, g_chase=0, g_late_bars=0, g_ticks=0, g_uni_short=0;
double        g_tick=0.01;
double        g_last_bid=0, g_last_ask=0;
bool          g_visual=false;
bool          g_ready=false;   // chỉ ghi kết quả khi khởi tạo thành công: không ghi đè lượt đã có

// ---------------------------------------------------------------- dữ liệu

bool PushRate(int tf, const MqlRates &r, datetime known)
  {
   ScpBar b;
   b.open_time=r.time;
   b.close_time=r.time+(datetime)PeriodSeconds(SIG_PERIODS[tf]);
   b.o=r.open; b.h=r.high; b.l=r.low; b.c=r.close;
   b.tick_volume=r.tick_volume;
   b.known_at=MathMax(known,b.close_time);
   b.known_at_msc=-1;
   b.received_mono=GetTickCount();
   b.complete=true;
   if(!g_s[tf].PushBar(b)) return false;
   g_last_pushed[tf]=r.time;
   return true;
  }

void Warmup()
  {
   for(int tf=0;tf<SIG_TF_COUNT;tf++)
     {
      MqlRates r[];
      ArraySetAsSeries(r,false);
      int got=CopyRates(_Symbol,SIG_PERIODS[tf],0,InpWarmupBars,r);
      // Chạy lại lịch sử từng nến như lúc vận hành: cản tạo ra rồi bị phá/đổi vai đúng thứ tự thời gian.
      for(int k=0;k<got-1;k++)
        {
         if(!PushRate(tf,r[k],0) || tf<SIG_M5) continue;
         g_book.ExpireBySource(tf,GetPointer(g_s[tf]));
         g_book.OnSourceBar(tf,GetPointer(g_s[tf]),g_seen[tf],r[k].close);
        }
      g_forming[tf]=(datetime)iTime(_Symbol,SIG_PERIODS[tf],0);
      if(tf==SIG_D1 && got>1) g_book.AddPeriodExtremes(SIG_LV_PD,g_s[tf].LastBar(),g_s[tf].Atr(),r[got-2].close);
      if(tf==SIG_W1 && got>1) g_book.AddPeriodExtremes(SIG_LV_PW,g_s[tf].LastBar(),g_s[tf].Atr(),r[got-2].close);
     }
   g_book.EnsureRound(SymbolInfoDouble(_Symbol,SYMBOL_BID),TimeCurrent());
  }

// Nạp nến đã đóng mới; `nb[tf]` = khung có nến mới.
void UpdateFrames(bool &nb[], datetime now)
  {
   for(int tf=0;tf<SIG_TF_COUNT;tf++)
     {
      nb[tf]=false;
      datetime t0=(datetime)iTime(_Symbol,SIG_PERIODS[tf],0);
      if(t0<=0 || t0==g_forming[tf]) continue;
      MqlRates r[];
      ArraySetAsSeries(r,false);
      int got=CopyRates(_Symbol,SIG_PERIODS[tf],g_last_pushed[tf]+1,t0-1,r);
      g_forming[tf]=t0;
      for(int k=0;k<got;k++)
        {
         if(r[k].time<=g_last_pushed[tf]) continue;
         datetime close_at=r[k].time+(datetime)PeriodSeconds(SIG_PERIODS[tf]);
         if(tf==SIG_M1 && now-close_at>2) g_late_bars++;
         if(PushRate(tf,r[k],now)) nb[tf]=true;
        }
     }
  }

void LoadNews()
  {
   g_news_n=0;
   ArrayResize(g_news,0,512);
   int fh=FileOpen("BotVang\\news_usd.csv",FILE_COMMON|FILE_READ|FILE_TXT|FILE_ANSI);
   if(fh==INVALID_HANDLE) return;
   while(!FileIsEnding(fh))
     {
      string line=FileReadString(fh);
      int p=StringFind(line,";");
      if(p<8) continue;
      datetime t=StringToTime(StringSubstr(line,0,p));
      if(t<=0) continue;
      ArrayResize(g_news,g_news_n+1,512);
      g_news[g_news_n++]=t;
     }
   FileClose(fh);
   ArraySort(g_news);
  }

// -1 thiếu lịch tin cho thời điểm này, 1 gần tin, 0 xa tin.
int NewsFlag(datetime now)
  {
   if(g_news_n==0 || now<g_news[0] || now>g_news[g_news_n-1]+86400) return -1;
   for(int i=0;i<g_news_n;i++)
      if(now>=g_news[i]-InpNewsBeforeMin*60 && now<=g_news[i]+InpNewsAfterMin*60) return 1;
   return 0;
  }

void RefreshNear(double bid, datetime now)
  {
   double radius=MathMax(6.0*g_s[SIG_M5].Atr(),3.0);
   g_near_n=g_book.Near(bid,radius,now,g_near);
   g_near_center=bid;
  }

// ---------------------------------------------------------------- tín hiệu

double TargetK(int dir, double edge, double bid, double ask, double buf, double spread, double r)
  {
   if(edge<=0 || r<=0) return 0;
   double k=(dir>0) ? ((edge-buf)-ask)/r : (bid-(edge+buf+spread))/r;
   return (k>0) ? k : 0;
  }

void HandleSignal(const SigSignal &g, datetime now, double bid, double ask)
  {
   bool limit=(g.reaction==SCP_RE_NONE); // lệnh chờ trên giấy: khớp ngay tại mốc, không chờ phản ứng
   if(!limit && now-g.bar_close>2) { g_stale++; return; }
   if(!limit && g.dir*(bid-g.bar_c)>InpChaseAtr*g.atr) { g_chase++; return; }
   double spread=ask-bid;
   double base=(g.dir>0) ? MathMin(g.far,g.ext) : MathMax(g.far,g.ext);
   double buf=MathMax(g.eps,spread);
   double atr5=g_s[SIG_M5].Atr();
   double e_m5=g_book.NearestAhead(g.dir,bid,false,now);
   MqlDateTime dt; TimeToStruct(now,dt);
   int news=NewsFlag(now);
   int scen=(g.type==SIG_LV_UNI) ? 3 : (g.type==SIG_LV_Z ? 6 : ((g.flip==0) ? 1 : (g.cont ? 5 : 2)));
   for(int v=0;v<3;v++)
     {
      double extra=SIG_SL_EXTRA[v]*atr5;
      double b0=base;
      // K3: dừng lỗ theo nhánh thao túng: 0 thân cực trị (tài liệu), 1 râu cực trị, 2 râu cực trị + 0,3 ATR M5.
      if(scen==3) { b0=(v==0) ? g.sl_body : g.sl_wick; extra=(v==2) ? 0.3*atr5 : 0; }
      double sl=(g.dir>0) ? b0-buf-extra : b0+buf+extra+spread;
      double r=(g.dir>0) ? ask-sl : sl-bid;
      if(r<=g_tick) continue;
      double e_htf=g_book.HtfTarget(g.dir,bid,ask,buf,r,now);
      // K3 Unicorn: đích là DOL của mô hình (đỉnh/đáy bằng nhau), không phải DOL chung.
      double e_dol=(scen==3) ? g.dol : g_book.DolTarget(g.dir,bid,ask,buf,r,now);
      double k[3];
      k[SIG_T_HTF]=TargetK(g.dir,e_htf,bid,ask,buf,spread,r);
      k[SIG_T_M5]=TargetK(g.dir,e_m5,bid,ask,buf,spread,r);
      k[SIG_T_DOL]=TargetK(g.dir,e_dol,bid,ask,buf,spread,r);
      if(scen==3 && k[SIG_T_DOL]<2.0) { if(!g.fake && !limit && v==0) g_uni_short++; continue; } // tài liệu: ít nhất 2R
      SigFeatures f;
      ZeroMemory(f);
      f.etf=g.etf; f.group=g.group; f.ltype=g.type; f.tier=g.tier; f.conf=g.conf;
      f.reaction=g.reaction; f.strict=g.strict; f.minor=g.minor; f.test_no=g.test_no; f.wick=g.wick;
      f.var_moc=g.var; f.var_sl=v; f.scen=scen; f.entry_mode=limit ? 1 : 0; f.flip_def=g.flip_def; f.wick_broken=g.wick_broken;
      f.news=news; f.bars_after=g.bars_after; f.hour=dt.hour; f.spread=spread; f.atr=g.atr;
      f.cost_r=(spread+2.0*InpSlipPerLeg)/r;
      f.disp=g.disp; f.body_max=g.body_max; f.bos=g.bos; f.rank=g.rank; f.brk_body=g.brk_body; f.merged=g.merged; f.ref_tf=g.ref_tf;
      if(g.fake) { g_trk.Open(SIG_K_FAKE,g.level_id,now,g.dir,bid,ask,r,k,f); continue; }
      long id=g_trk.OpenWithControls(now,g.dir,bid,ask,r,k,f);
      if(!limit && v==0 && id>0 && g_visual && InpDraw && (g.var==0 || !g.wick))
         SigDrawSignal(id,now,g.dir,g.dir>0?ask:bid,sl,e_htf,
                       SigScenName(scen)+" "+SigGroupName(g.group)+" "+SigTypeName(g.type)+" "+
                       SigReactionName(g.reaction));
     }
   if(limit) { g_limit_records++; return; }
   if(g.fake) g_fake_signals++;
   else
     {
      g_signals++;
      // Chiều của K2 thật gần nhất làm bối cảnh tiếp diễn K5 (SPEC 23.3).
      if((scen==2 || scen==5 || scen==6) && g.test_no==0 && (g.var==0 || !g.wick)) g_book.SetTrend(g.dir);
     }
  }

// ---------------------------------------------------------------- ghi kết quả

string RecLine(const SigRec &x)
  {
   string kinds[4]={"that","nguoc","ngau_nhien","can_gia"};
   const SigFeatures f=x.f;
   string s=IntegerToString(x.id)+";"+kinds[x.kind]+";"+IntegerToString(x.parent)+";"+
            TimeToString(x.t0,TIME_DATE|TIME_SECONDS)+";"+(x.dir>0?"mua":"ban")+";"+
            DoubleToString(x.entry,3)+";"+DoubleToString(x.r,3)+";"+
            DoubleToString(x.k[0],2)+";"+DoubleToString(x.k[1],2)+";"+DoubleToString(x.k[2],2)+";"+
            SigScenName(f.scen)+";"+SigGroupName(f.group)+";"+SigTypeName(f.ltype)+";"+
            IntegerToString(f.tier)+";"+IntegerToString(f.conf)+";"+SigReactionName(f.reaction)+";"+(f.strict?"1":"0")+";"+(f.entry_mode==1?"cho_giay":"thi_truong")+";"+
            (f.etf==0?"M1":"M5")+";"+IntegerToString(f.test_no)+";"+IntegerToString(f.var_moc)+";"+IntegerToString(f.var_sl)+";"+
            IntegerToString(f.flip_def)+";"+(f.wick_broken?"1":"0")+";"+IntegerToString(f.news)+";"+IntegerToString(f.hour)+";"+
            DoubleToString(f.spread,3)+";"+DoubleToString(f.atr,3)+";"+DoubleToString(f.cost_r,3)+";"+
            DoubleToString(f.disp,2)+";"+DoubleToString(f.body_max,2)+";"+IntegerToString(f.bos)+";"+IntegerToString(f.rank)+";"+
            DoubleToString(f.brk_body,2)+";"+IntegerToString(f.merged)+";"+SigRefName(f.ref_tf);
   for(int i=0;i<SIG_NR;i++) s+=";"+IntegerToString(x.rs[i])+";"+DoubleToString(x.rr[i],3);
   for(int j=0;j<SIG_NS;j++) s+=";"+IntegerToString(x.ss[j])+";"+DoubleToString(x.sr[j],3);
   s+=";"+DoubleToString(x.mfe,3)+";"+DoubleToString(x.mae,3);
   for(int h=0;h<SIG_NH;h++) s+=";"+DoubleToString(x.hf[h],3)+";"+DoubleToString(x.ha[h],3);
   return s;
  }

// Bản ghi đã xong được ghi/chia nhóm ngay rồi bỏ khỏi bộ nhớ: lượt 6 tháng không giữ hàng triệu bản ghi.
void DrainDone()
  {
   int n=g_trk.DoneCount();
   if(n==0) return;
   for(int i=0;i<n;i++)
     {
      SigRec x=g_trk.Done(i);
      if(g_fh_signals!=INVALID_HANDLE) FileWriteString(g_fh_signals,RecLine(x)+"\r\n");
      g_rep.Classify(x,true);
     }
   g_trk.ClearDone();
  }

void OpenSignalsFile()
  {
   int fh=FileOpen(g_folder+"\\tin_hieu.csv",FILE_COMMON|FILE_WRITE|FILE_TXT|FILE_UNICODE);
   if(fh!=INVALID_HANDLE)
     {
      string h="id;loai;goc;gio;chieu;gia_vao;R_gia;k_can_lon;k_can_M5;k_DOL;kich_ban;nhom_can;loai_can;bac;trung_can;phan_ung;"
               "dong_vuot_mep_gan;cach_vao;khung_vao;lan_cham_truoc;moc;dung;pha_def;rau_da_vuot;tin;gio_san;spread;atr;chi_phi_R;"
               "luc_bat_ATR;than_dong_luc_ATR;pha_cau_truc;do_lon_dinh;than_nen_pha_ATR;so_tin_hieu_gop;tinh_chinh";
      string rn[SIG_NR]={"dua_1R","dua_1.5R","dua_2R","dua_3R","dua_can_lon","dua_DOL"};
      for(int i=0;i<SIG_NR;i++) h+=";"+rn[i]+"_kq;"+rn[i]+"_R";
      for(int j=0;j<SIG_NS;j++) h+=";hai_phan"+IntegerToString(j)+"_kq;hai_phan"+IntegerToString(j)+"_R";
      h+=";mfe;mae;mfe1;mae1;mfe5;mae5;mfe15;mae15;mfe60;mae60;mfe240;mae240";
      FileWriteString(fh,h+"\r\n");
     }
   g_fh_signals=fh;
  }

void WriteResults()
  {
   string head="Công cụ đo tín hiệu HTF-ZONE — "+SCP_SPEC_VERSION+" + SPEC 22–24\r\n"+
               "Lượt: "+InpRunName+" | "+_Symbol+" | seed="+(string)InpSeed+" | trượt/chặng="+DoubleToString(InpSlipPerLeg,2)+
               " | theo dõi tối đa="+(string)InpMaxHoldMin+" phút | né tin -"+(string)InpNewsBeforeMin+"/+"+(string)InpNewsAfterMin+
               " phút | lịch tin: "+(g_news_n>0?(string)g_news_n+" sự kiện":"THIẾU")+
               " | tin_hieu.csv: "+(InpWriteSignals?"có ghi":"không ghi")+"\r\n"+
               "Tick: "+(string)g_ticks+" | nến M1 nhận muộn >2s: "+(string)g_late_bars+"\r\n"+
               "Cản tạo: M5_tam="+(string)g_book.Created(0)+" M15="+(string)g_book.Created(1)+" M30="+(string)g_book.Created(2)+
               " H1="+(string)g_book.Created(3)+" H4="+(string)g_book.Created(4)+" D1="+(string)g_book.Created(5)+
               " W1="+(string)g_book.Created(6)+" ngay_truoc="+(string)g_book.Created(7)+" tuan_truoc="+(string)g_book.Created(8)+
               " so_tron="+(string)(g_book.Created(9)+g_book.Created(10)+g_book.Created(11))+
               " | cản giả="+(string)g_book.FakeCreated()+" | bị phá="+(string)g_book.Broken()+" | hết tuổi="+(string)g_book.Aged()+
               " | bỏ vì đầy="+(string)g_book.Dropped()+"\r\n"+
               "Chạm="+(string)g_det.Touches()+" | phá trong 1 nhịp="+(string)g_det.BrokenInSwing()+
               " | hết hạn chờ phản ứng="+(string)g_det.Expired()+" | có phản ứng="+(string)g_det.Reacted()+
               " | cản tạm M5 bị loại="+(string)g_det.MinorRejected()+
               " | lệnh chờ trên giấy khớp="+(string)g_limit_records+" (chỉ để so sánh, bot không dùng)\r\n"+
               "Tín hiệu thật="+(string)g_signals+" | từ cản giả="+(string)g_fake_signals+" | bỏ vì quá 2 giây="+(string)g_stale+
               " | bỏ vì giá chạy xa="+(string)g_chase+" | ngẫu nhiên mở="+(string)g_trk.RtMade()+
               " | ngẫu nhiên thiếu dữ liệu="+(string)g_trk.RtMissed()+"\r\n"+
               "Vùng Z 411 tạo="+(string)g_book.ZonesMade()+" | Unicorn tạo="+(string)g_book.UnicornsMade()+
               " | Unicorn bỏ vì DOL < 2R="+(string)g_uni_short+"\r\n"+
               "Tín hiệu gộp vào tín hiệu khác ở cản chồng nhau="+(string)g_det.Merged()+
               " | lần chạm đo phản ứng="+(string)g_probe.DoneCount()+" (xem phan_ung_can.csv)\r\n";
   int ft=FileOpen(g_folder+"\\tong_ket.txt",FILE_COMMON|FILE_WRITE|FILE_TXT|FILE_UNICODE);
   if(ft!=INVALID_HANDLE)
     {
      FileWriteString(ft,head);
      g_rep.WriteSummary(ft);
      FileClose(ft);
     }
   int fp=FileOpen(g_folder+"\\phan_ung_can.csv",FILE_COMMON|FILE_WRITE|FILE_TXT|FILE_UNICODE);
   if(fp!=INVALID_HANDLE) { g_probe.Write(fp,head); FileClose(fp); }
   int fn=FileOpen(g_folder+"\\nhom.csv",FILE_COMMON|FILE_WRITE|FILE_TXT|FILE_UNICODE);
   if(fn!=INVALID_HANDLE) { g_rep.Write(fn,g_signals,g_fake_signals,head); FileClose(fn); }
   Print("[SIGLAB] ",head);
  }

// ---------------------------------------------------------------- sự kiện MT5

int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER)) { Print("[SIGLAB] chỉ chạy trong máy thử"); return INIT_FAILED; }
   if(InpReactBars<1 || InpMaxHoldMin<240 || InpRandomCopies<0 || InpRandomCopies>10 || InpSlipPerLeg<0 || InpChaseAtr<=0)
     { Print("[SIGLAB] tham số không hợp lệ"); return INIT_PARAMETERS_INCORRECT; }
   g_folder="BotScp\\SignalLab\\"+InpRunName;
   if(FileIsExist(g_folder+"\\tong_ket.txt",FILE_COMMON) || FileIsExist(g_folder+"\\vung_htf.csv",FILE_COMMON))
     { Print("[SIGLAB] tên lượt đã tồn tại; chọn InpRunName mới, không ghi đè bằng chứng"); return INIT_FAILED; }
   FolderCreate(g_folder,FILE_COMMON);
   g_visual=(bool)MQLInfoInteger(MQL_VISUAL_MODE);
   g_tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   for(int tf=0;tf<SIG_TF_COUNT;tf++)
     { g_s[tf].Reset(); g_s[tf].Init(SIG_PIVOT_AS[tf]); g_forming[tf]=0; g_last_pushed[tf]=0; g_seen[tf]=0; }
   g_book.Init(g_tick,InpSeed,InpFakeLevels);
   for(int tf=0;tf<SIG_TF_COUNT;tf++) g_book.SetSeries(tf,GetPointer(g_s[tf]));
   g_fh_levels=FileOpen(g_folder+"\\vung_htf.csv",FILE_COMMON|FILE_WRITE|FILE_TXT|FILE_UNICODE);
   if(g_fh_levels!=INVALID_HANDLE)
      FileWriteString(g_fh_levels,"id;that_gia;goc;nhom;loai;vai_tro;day;dinh;gio_hinh_thanh;gio_biet;gio_het;ly_do_het;so_lan_cham;"
                      "luc_bat_ATR;than_dong_luc_ATR;pha_cau_truc;do_lon_dinh;than_nen_pha_ATR;tinh_chinh\r\n");
   g_book.SetLog(g_fh_levels);
   g_det.Init(InpReactBars);
   g_trk.Init(InpSeed+7,InpMaxHoldMin,InpRandomCopies);
   g_rep.Init(InpSlipPerLeg);
   g_probe.Init();
   if(InpWriteSignals)
     {
      OpenSignalsFile();
      g_fh_touches=FileOpen(g_folder+"\\cham_can.csv",FILE_COMMON|FILE_WRITE|FILE_TXT|FILE_UNICODE);
      g_probe.SetRaw(g_fh_touches);
     }
   LoadNews();
   Warmup();
   g_ready=true;
   Print("[SIGLAB] bắt đầu ",InpRunName," | lịch tin: ",(g_news_n>0?(string)g_news_n+" sự kiện":"THIẾU"),
         " | cản nạp trước: ",g_book.Count());
   return INIT_SUCCEEDED;
  }

void OnTick()
  {
   MqlTick t;
   if(!SymbolInfoTick(_Symbol,t) || t.bid<=0 || t.ask<t.bid) return;
   g_ticks++;
   datetime now=t.time;
   g_last_bid=t.bid; g_last_ask=t.ask;
   bool nb[SIG_TF_COUNT];
   UpdateFrames(nb,now);
   // Thứ tự: phá trong một nhịp → phản ứng ở nến vừa đóng (với cản đã có) → cản mới/hết hiệu lực từ khung nguồn.
   if(nb[SIG_M1] && g_s[SIG_M1].Count()>1) g_probe.OnM1Close(g_s[SIG_M1].LastBar());
   if(nb[SIG_M5] && g_s[SIG_M5].Count()>1)
     {
      double eps5=MathMax(2.0*g_tick,SCP_K_BUFFER*g_s[SIG_M5].Atr());
      g_det.OnM5Close(g_s[SIG_M5].LastBar(),eps5,g_book);
      g_probe.OnM5Close(g_s[SIG_M5].LastBar(),eps5);
     }
   if(nb[SIG_M1] && InpUseM1) g_det.OnEntryBarClosed(0,GetPointer(g_s[SIG_M1]),g_book,g_near,g_near_n,g_tick);
   if(nb[SIG_M5] && InpUseM5) g_det.OnEntryBarClosed(1,GetPointer(g_s[SIG_M5]),g_book,g_near,g_near_n,g_tick);
   bool levels_changed=false;
   for(int tf=SIG_M5;tf<SIG_TF_COUNT;tf++)
     {
      if(!nb[tf]) continue;
      g_book.ExpireBySource(tf,GetPointer(g_s[tf]));
      g_book.OnSourceBar(tf,GetPointer(g_s[tf]),g_seen[tf],t.bid);
      levels_changed=true;
     }
   if(nb[SIG_D1]) g_book.AddPeriodExtremes(SIG_LV_PD,g_s[SIG_D1].LastBar(),g_s[SIG_D1].Atr(),t.bid);
   if(nb[SIG_W1]) g_book.AddPeriodExtremes(SIG_LV_PW,g_s[SIG_W1].LastBar(),g_s[SIG_W1].Atr(),t.bid);
   if(nb[SIG_M1]) { g_book.EnsureRound(t.bid,now); levels_changed=true; }
   double radius=MathMax(6.0*g_s[SIG_M5].Atr(),3.0);
   if(levels_changed || MathAbs(t.bid-g_near_center)>radius*0.5) RefreshNear(t.bid,now);
   SigSignal sg[];
   int n=g_det.Take(sg);
   for(int i=0;i<n;i++) HandleSignal(sg[i],now,t.bid,t.ask);
   g_det.OnTick(g_book,g_near,g_near_n,t.bid,now,GetPointer(g_s[SIG_M1]),GetPointer(g_s[SIG_M5]),g_tick,
                InpUseM5Minor,InpUseM1,InpUseM5);
   SigTouch tc[];
   int nt=g_det.TakeTouches(tc);
   for(int i=0;i<nt;i++) g_probe.Open(tc[i],t.bid,g_s[SIG_M5].Atr());
   g_probe.OnTick(t.bid);
   int secs=ScpSecondsToSessionEnd(_Symbol,now);
   g_trk.Update(now,t.bid,t.ask,secs>0 && secs<=60);
   DrainDone();
   if(g_visual && InpDraw && nb[SIG_M15]) SigDrawLevels(g_book,now,t.bid,15.0*g_s[SIG_H1].Atr());
  }

void OnDeinit(const int reason)
  {
   if(!g_ready) return;
   g_trk.CloseAll(g_last_bid,g_last_ask);
   DrainDone();
   if(g_fh_signals!=INVALID_HANDLE) FileClose(g_fh_signals);
   g_probe.CloseAll(TimeCurrent());
   if(g_fh_touches!=INVALID_HANDLE) FileClose(g_fh_touches);
   g_book.FlushLog();
   if(g_fh_levels!=INVALID_HANDLE) FileClose(g_fh_levels);
   WriteResults();
  }
