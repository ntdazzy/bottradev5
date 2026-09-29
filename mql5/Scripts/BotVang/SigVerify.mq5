// SigVerify.mq5 — ca kiểm công cụ đo tín hiệu HTF-ZONE (SPEC 22–23) bằng nến dựng sẵn; không đọc giá sàn, không gửi lệnh.
// In PASS/FAIL từng ca và dòng tổng "[SIG_VERIFY] TOTAL n | PASS a | FAIL b".
#property script_show_inputs

#include <BotVang\ScpTypes.mqh>
#include <BotVang\ScpSeries.mqh>
#include <BotVang\SigLevels.mqh>
#include <BotVang\SigDetect.mqh>
#include <BotVang\SigTrack.mqh>

input bool InpCloseTerminal = false;

int g_pass=0, g_fail=0;
datetime g_t0=D'2026.03.02 00:00';

void Check(const string name, bool ok, const string detail="")
  {
   if(ok) g_pass++; else g_fail++;
   Print("[SIG_VERIFY] ",(ok?"PASS ":"FAIL "),name,(detail!=""?" | "+detail:""));
  }

bool Near(double a, double b, double tol=1e-6) { return MathAbs(a-b)<=tol; }

ScpBar Bar(int idx, int sec, double o, double h, double l, double c)
  {
   ScpBar b;
   b.open_time=g_t0+(datetime)(idx*sec);
   b.close_time=b.open_time+(datetime)sec;
   b.o=o; b.h=h; b.l=l; b.c=c;
   b.tick_volume=10; b.known_at=b.close_time; b.known_at_msc=-1; b.received_mono=0; b.complete=true;
   return b;
  }

// Đẩy nến vào chuỗi khung nguồn và cập nhật sổ cản đúng thứ tự như EA.
void Feed(ScpSeries &s, SigLevelBook &book, long &seen, int tf, const ScpBar &b)
  {
   // Nến dựng sai (bị từ chối) làm lệch cả ca kiểm: báo ngay.
   if(!s.PushBar(b)) Check("Nến dựng hợp lệ lúc "+TimeToString(b.open_time),false);
   book.ExpireBySource(tf,GetPointer(s));
   book.OnSourceBar(tf,GetPointer(s),seen,b.c);
  }

int FindLevel(SigLevelBook &book, int type, int flip, SigLevel &out, int role=0)
  {
   for(int i=0;i<book.Count();i++)
     {
      SigLevel z;
      if(book.Get(i,z) && z.type==type && z.flip==flip && (role==0 || z.role==role)) { out=z; return i; }
     }
   return -1;
  }

// Chuỗi M15 nền: nến doji biên độ 1 quanh 100 để có ATR ~1 và không có đỉnh/đáy.
void Base(ScpSeries &s, SigLevelBook &book, long &seen, int count)
  {
   for(int i=0;i<count;i++) Feed(s,book,seen,SIG_M15,Bar(i,900,100,100.5,99.5,100));
  }

// Đỉnh xác nhận tại nến p (tăng) + nến sau giảm → vùng râu và Classic A.
int BuildPivotHigh(ScpSeries &s, SigLevelBook &book, long &seen, int start)
  {
   int i=start;
   Feed(s,book,seen,SIG_M15,Bar(i++,900,100,102,99.8,101));        // p: tăng, H=102
   Feed(s,book,seen,SIG_M15,Bar(i++,900,101,101.1,100.2,100.3));   // p+1: giảm
   Feed(s,book,seen,SIG_M15,Bar(i++,900,100.3,100.6,99.9,100.3));  // p+2
   Feed(s,book,seen,SIG_M15,Bar(i++,900,100.3,100.6,99.9,100.3));  // p+3: xác nhận N=3
   return i;
  }

void TestLevels()
  {
   ScpSeries s; s.Init(SCP_TF_M15);
   SigLevelBook book; book.Init(0.01,1,false);
   long seen=0;
   Base(s,book,seen,20);
   int next=BuildPivotHigh(s,book,seen,20);
   SigLevel z;
   int ip=FindLevel(book,SIG_LV_PIVOT,0,z,-1);
   Check("L1 đỉnh râu: có vùng kháng cự",ip>=0);
   if(ip>=0)
     {
      Check("L1 vùng = [max(O,C), H] = [101, 102]",Near(z.bottom,101) && Near(z.top,102),
            DoubleToString(z.bottom,3)+"-"+DoubleToString(z.top,3));
      Check("L1 vai kháng cự, có râu",z.role==-1 && z.wick);
      Check("L1 biết lúc nến p+3 đóng",z.known_at==g_t0+(datetime)(24*900),TimeToString(z.known_at));
     }
   int ic=FindLevel(book,SIG_LV_CLASSIC,0,z);
   Check("L2 Classic A: có mức",ic>=0);
   if(ic>=0) Check("L2 mức C(c1)=101, vùng [101, 102]",Near(z.lvl,101) && Near(z.bottom,101) && Near(z.top,102));
   // Râu vượt mép xa nhưng thân đóng dưới: đánh dấu và tạo bản đổi vai kiểu râu.
   Feed(s,book,seen,SIG_M15,Bar(next++,900,100.5,102.4,100.4,101.5));
   ip=FindLevel(book,SIG_LV_PIVOT,0,z,-1);
   Check("Phá bằng râu: cản gốc còn sống, cờ râu vượt",ip>=0 && z.alive && z.wick_broken);
   SigLevel f;
   int iflip=FindLevel(book,SIG_LV_PIVOT,1,f,1);
   Check("Phá bằng râu: có bản đổi vai hỗ trợ, def=2",iflip>=0 && f.role==1 && f.flip_def==2,
         iflip>=0 ? "role="+(string)f.role+" def="+(string)f.flip_def : "không có");
   // Thân đóng qua mép xa: cản gốc chết, bản đổi vai cũ được ghi thêm def=1 (không tạo bản thứ hai).
   Feed(s,book,seen,SIG_M15,Bar(next++,900,101.5,102.8,101.4,102.6));
   ip=FindLevel(book,SIG_LV_PIVOT,0,z,-1);
   Check("Phá bằng thân: cản gốc chết vì bị phá",ip>=0 && !z.alive && z.dead_why==1);
   int flips=0;
   for(int i=0;i<book.Count();i++) { SigLevel q; if(book.Get(i,q) && q.type==SIG_LV_PIVOT && q.flip==1 && q.role==1) { flips++; f=q; } }
   Check("Phá bằng thân: đúng 1 bản đổi vai, def=3",flips==1 && f.flip_def==3,"flips="+(string)flips+" def="+(string)f.flip_def);
  }

void TestGapDoji()
  {
   ScpSeries s; s.Init(SCP_TF_M15);
   SigLevelBook book; book.Init(0.01,1,false);
   long seen=0;
   Base(s,book,seen,20);
   // Gap giảm: hai nến giảm, nến 2 thân lớn.
   Feed(s,book,seen,SIG_M15,Bar(20,900,100,100.2,99.4,99.5));
   Feed(s,book,seen,SIG_M15,Bar(21,900,99.5,99.7,98.2,98.3));
   SigLevel z;
   int ig=FindLevel(book,SIG_LV_GAP,0,z);
   Check("L3 Gap giảm: có vùng",ig>=0);
   if(ig>=0) Check("L3 mức C(c1)=99.5, vùng [L(c1)=99.4, max(H(c2),C(c1))=99.7], kháng cự",
                   Near(z.lvl,99.5) && Near(z.bottom,99.4) && Near(z.top,99.7) && z.role==-1,
                   DoubleToString(z.bottom,2)+"-"+DoubleToString(z.top,2));
   // Doji SnR giảm: c1 giảm mạnh, doji, c3 giảm mạnh đóng dưới đáy doji.
   Feed(s,book,seen,SIG_M15,Bar(22,900,98.3,98.4,97.5,97.6));
   Feed(s,book,seen,SIG_M15,Bar(23,900,97.6,98.1,97.5,97.62));
   Feed(s,book,seen,SIG_M15,Bar(24,900,97.62,97.7,96.7,96.8));
   int id=FindLevel(book,SIG_LV_DOJI,0,z);
   Check("L4 Doji SnR giảm: có vùng",id>=0);
   if(id>=0) Check("L4 vùng [O(c3)=97.62, đỉnh râu doji=98.1], kháng cự",
                   Near(z.bottom,97.62) && Near(z.top,98.1) && z.role==-1,
                   DoubleToString(z.bottom,2)+"-"+DoubleToString(z.top,2));
   // Không dùng trước lúc được biết.
   int idx=-1;
   for(int i=0;i<book.Count();i++) { SigLevel q; if(book.Get(i,q) && q.type==SIG_LV_DOJI) idx=i; }
   Check("Cản chưa dùng được trước lúc biết",idx>=0 && !book.Usable(idx,g_t0+(datetime)(24*900)));
  }

void TestTracker()
  {
   SigTracker trk; trk.Init(1,1440,0);
   SigFeatures f; ZeroMemory(f);
   double k[3]={3.0,0,0};
   // Mua: vào Ask 100.2, R = 1 (dừng Bid 99.2).
   trk.Open(SIG_K_SIG,0,g_t0,1,100.0,100.2,1.0,k,f);
   trk.Update(g_t0+1,101.2,101.4,false);   // +1R
   trk.Update(g_t0+2,101.7,101.9,false);   // +1.5R
   trk.Update(g_t0+3,100.2,100.4,false);   // về giá vào: phần còn lại chốt phần đầu dừng ở giá vào
   trk.Update(g_t0+4,98.9,99.1,false);     // nhảy qua dừng: -1.3R
   trk.CloseAll(98.9,99.1);
   SigRec x=trk.Done(0);
   Check("Đua 1R thắng đúng +1R",x.rs[0]==SIG_WIN && Near(x.rr[0],1.0));
   Check("Đua 1.5R thắng đúng +1.5R",x.rs[1]==SIG_WIN && Near(x.rr[1],1.5));
   Check("Đua 2R thua, dừng khớp ở giá nhảy -1.3R",x.rs[2]==SIG_LOSS && Near(x.rr[2],-1.3,1e-6),DoubleToString(x.rr[2],3));
   Check("Đua đích 3R thua",x.rs[4]==SIG_LOSS);
   Check("Hai phần 1R+3R: phần đầu 0.5R, phần sau ra ở giá vào → 0.5R",x.ss[0]==SIG_BE && Near(x.sr[0],0.5),
         DoubleToString(x.sr[0],3));
   Check("Hai phần 1.5R+3R: 0.75R",x.ss[1]==SIG_BE && Near(x.sr[1],0.75),DoubleToString(x.sr[1],3));
   Check("Hai phần có cản M5 không có đích: không áp dụng",x.ss[2]==SIG_NA);
   Check("DOL không có: đua DOL không áp dụng",x.rs[5]==SIG_NA);
   Check("Cực trị thuận/ngược",Near(x.mfe,1.5) && Near(x.mae,-1.3));
   // Bán: vào Bid 100, thoát bằng Ask.
   SigTracker t2; t2.Init(1,1440,0);
   double k2[3]={2.0,0,0};
   t2.Open(SIG_K_SIG,0,g_t0,-1,100.0,100.2,1.0,k2,f);
   t2.Update(g_t0+1,97.8,98.0,false);      // Ask 98 → +2R
   t2.CloseAll(97.8,98.0);
   SigRec y=t2.Done(0);
   Check("Bán thoát bằng Ask: đua 2R thắng",y.rs[2]==SIG_WIN && Near(y.rr[2],2.0));
   Check("Bán: hai phần 1R + đích 2R = 1.5R",y.ss[0]==SIG_WIN && Near(y.sr[0],1.5),DoubleToString(y.sr[0],3));
  }

void TestDetector()
  {
   SigLevelBook book; book.Init(0.01,1,false);
   ScpSeries m1; m1.Init(SCP_TF_M1);
   ScpSeries m5; m5.Init(SCP_TF_M5);
   for(int i=0;i<20;i++) { m1.PushBar(Bar(i,60,101.5,102,101,101.5)); m5.PushBar(Bar(i,300,101.5,102,101,101.5)); }
   book.EnsureRound(101.5,g_t0);
   int near[]; int nn=book.Near(101.5,5.0,g_t0+1200,near);
   SigDetector det; det.Init(3);
   // Nến M1 đóng hoàn toàn trên mức 100: đặt phía tiếp cận từ trên.
   m1.PushBar(Bar(20,60,101.5,102,101,101.5));
   det.OnEntryBarClosed(0,GetPointer(m1),book,near,nn,0.01);
   det.OnTick(book,near,nn,100.05,g_t0+(datetime)(21*60+10),GetPointer(m1),GetPointer(m5),0.01,false,true,false);
   Check("Chạm mức số tròn 100 từ trên",det.Touches()==1,"chạm="+(string)det.Touches());
   // Nến rút râu dưới (P1 mua) đóng trên mức.
   m1.PushBar(Bar(21,60,100.5,100.65,99.95,100.6));
   det.OnEntryBarClosed(0,GetPointer(m1),book,near,nn,0.01);
   SigSignal sg[];
   int n=det.Take(sg);
   Check("Chạm 100.05 (chưa tới mốc) không khớp lệnh chờ trên giấy",det.LimitFills()==0);
   Check("Phản ứng rút râu phát 1 tín hiệu mua",n==1 && sg[0].dir==1 && sg[0].reaction==SCP_RE_P1,
         "n="+(string)n+(n>0?" dir="+(string)sg[0].dir+" re="+(string)sg[0].reaction:""));
   if(n>0) Check("Tín hiệu giữ cực trị lần chạm",Near(sg[0].ext,100.05));
   // Mở lại cần nến rời hẳn: chạm tiếp ngay không mở lần chạm mới.
   det.OnTick(book,near,nn,100.02,g_t0+(datetime)(22*60+5),GetPointer(m1),GetPointer(m5),0.01,false,true,false);
   Check("Không mở lại khi chưa rời hẳn mức",det.Touches()==1);
  }

// Lệnh chờ trên giấy tại mốc: chạm trong dung sai chưa khớp; Bid tới đúng mốc mới khớp, chỉ một lần.
void TestPaperLimit()
  {
   SigLevelBook book; book.Init(0.01,1,false);
   ScpSeries m1; m1.Init(SCP_TF_M1);
   ScpSeries m5; m5.Init(SCP_TF_M5);
   for(int i=0;i<21;i++) { m1.PushBar(Bar(i,60,101.5,102,101,101.5)); m5.PushBar(Bar(i,300,101.5,102,101,101.5)); }
   book.EnsureRound(101.5,g_t0);
   int near[]; int nn=book.Near(101.5,5.0,g_t0+1300,near);
   SigDetector det; det.Init(3);
   det.OnEntryBarClosed(0,GetPointer(m1),book,near,nn,0.01);
   datetime t=g_t0+(datetime)(21*60+5);
   det.OnTick(book,near,nn,100.08,t,GetPointer(m1),GetPointer(m5),0.01,false,true,false);
   SigSignal sg[];
   int n=det.Take(sg);
   Check("Chờ trên giấy: chạm trong dung sai (100.08) chưa khớp",det.Touches()==1 && n==0,"chạm="+(string)det.Touches()+" n="+(string)n);
   det.OnTick(book,near,nn,99.99,t+3,GetPointer(m1),GetPointer(m5),0.01,false,true,false);
   n=det.Take(sg);
   Check("Chờ trên giấy: Bid tới mốc 100 thì khớp, không cần phản ứng",n==1 && sg[0].reaction==SCP_RE_NONE && sg[0].dir==1,
         "n="+(string)n);
   det.OnTick(book,near,nn,99.90,t+6,GetPointer(m1),GetPointer(m5),0.01,false,true,false);
   n=det.Take(sg);
   Check("Chờ trên giấy: chỉ khớp một lần mỗi lần chạm",n==0 && det.LimitFills()==1);
  }

void OnStart()
  {
   TestLevels();
   TestGapDoji();
   TestTracker();
   TestDetector();
   TestPaperLimit();
   Print("[SIG_VERIFY] TOTAL ",g_pass+g_fail," | PASS ",g_pass," | FAIL ",g_fail);
   if(InpCloseTerminal) TerminalClose(0);
  }
