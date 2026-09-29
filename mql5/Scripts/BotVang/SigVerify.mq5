// SigVerify.mq5 — ca kiểm công cụ đo tín hiệu HTF-ZONE (SPEC 22–23) bằng nến dựng sẵn; không đọc giá sàn, không gửi lệnh.
// In PASS/FAIL từng ca và dòng tổng "[SIG_VERIFY] TOTAL n | PASS a | FAIL b".
#property script_show_inputs

#include <BotVang\ScpTypes.mqh>
#include <BotVang\ScpSeries.mqh>
#include <BotVang\SigLevels.mqh>
#include <BotVang\SigDetect.mqh>
#include <BotVang\SigTrack.mqh>
#include <BotVang\SigProbe.mqh>

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

// Lỗi 29/09 (đọc mã): tuổi cản tính theo số nến trong bộ nhớ chuỗi (tối đa 1.500); khi đầy, số này đứng yên
// nên cản tạo sau đó không bao giờ hết tuổi (SPEC 23.2: hết hạn sau 200 nến nguồn).
void TestAgeAfterFull()
  {
   ScpSeries s; s.Init(SCP_TF_M15);
   SigLevelBook book; book.Init(0.01,1,false);
   long seen=0;
   Base(s,book,seen,1600);
   int next=BuildPivotHigh(s,book,seen,1600);
   SigLevel z;
   int ip=FindLevel(book,SIG_LV_PIVOT,0,z,-1);
   bool alive0=(ip>=0 && z.alive);
   for(int i=0;i<SIG_LEVEL_AGE+5;i++) Feed(s,book,seen,SIG_M15,Bar(next+i,900,100,100.5,99.5,100));
   ip=FindLevel(book,SIG_LV_PIVOT,0,z,-1);
   Check("Cản hết tuổi sau 200 nến kể cả khi chuỗi đã đầy 1.500 nến",alive0 && ip>=0 && !z.alive && z.dead_why==2,
         "tạo="+(string)alive0+" còn="+(string)(ip>=0 && z.alive)+" lý do="+(string)z.dead_why);
  }

// Lỗi 29/09 (chạy máy thử thật): nến vừa có râu dưới xuyên hỗ trợ đổi vai vừa đóng phá lên kháng cự
// làm bản đổi vai mới bị xét lại ngay trên chính nến đó → chuỗi đổi vai vô tận.
void TestFlipChain()
  {
   ScpSeries s; s.Init(SCP_TF_M15);
   SigLevelBook book; book.Init(0.01,1,false);
   long seen=0;
   Base(s,book,seen,20);
   int next=BuildPivotHigh(s,book,seen,20);
   int before=book.Count();
   // Nến tăng lớn: đáy 100.4 dưới mép dưới 101, đóng 102.6 trên mép trên 102.
   Feed(s,book,seen,SIG_M15,Bar(next,900,100.9,102.7,100.4,102.6));
   int flips=0;
   for(int i=0;i<book.Count();i++) { SigLevel q; if(book.Get(i,q) && q.type==SIG_LV_PIVOT && q.flip>=1) flips++; }
   Check("Nến vừa xuyên râu vừa đóng phá: đúng 1 bản đổi vai, không chuỗi",flips==1,"flips="+(string)flips);
   Check("Số lần bị phá trên một nến không vượt số cản cũ",book.Broken()<=before,
         "bị phá="+(string)book.Broken()+" cản trước="+(string)before);
  }

// Lỗi 29/09 (máy thử thật: 143.572 lần bị phá/tuần): giá dao động qua lại quanh một cản làm nó đổi vai mãi,
// mỗi lần lại được làm mới tuổi → cản không bao giờ hết, số cản và tín hiệu tăng không giới hạn.
void TestFlipOscillation()
  {
   ScpSeries s; s.Init(SCP_TF_M15);
   SigLevelBook book; book.Init(0.01,1,false);
   long seen=0;
   Base(s,book,seen,20);
   int next=BuildPivotHigh(s,book,seen,20);
   for(int k=0;k<20;k++)
     {
      if(k%2==0) Feed(s,book,seen,SIG_M15,Bar(next++,900,101.5,102.8,101.4,102.6));
      else Feed(s,book,seen,SIG_M15,Bar(next++,900,101.9,102.0,100.3,100.4));
     }
   int flips=0, maxflip=0;
   for(int i=0;i<book.Count();i++)
     {
      SigLevel q;
      if(book.Get(i,q) && q.type==SIG_LV_PIVOT && q.flip>=1) { flips++; maxflip=MathMax(maxflip,q.flip); }
     }
   Check("Dao động quanh cản: chỉ đổi vai một lần (SPEC 23.2)",maxflip<=1 && flips<=1,
         "bản đổi vai="+(string)flips+" bậc cao nhất="+(string)maxflip);
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
   // Bản ghi xong được bỏ khỏi bộ nhớ sau khi ghi; bản ghi sau vẫn vào đúng chỗ.
   t2.ClearDone();
   bool empty=(t2.DoneCount()==0);
   long id3=t2.Open(SIG_K_SIG,0,g_t0+10,1,100.0,100.2,1.0,k2,f);
   t2.CloseAll(100.0,100.2);
   Check("Xóa bản ghi đã xong: bộ đếm về 0, bản ghi mới vào đúng chỗ",empty && t2.DoneCount()==1 && t2.Done(0).id==id3);
  }

// Đích cản khung lớn: bỏ cản cách giá vào dưới 1R (SPEC 23.4), lấy cản kế tiếp.
void TestHtfTarget()
  {
   SigLevelBook book; book.Init(0.01,1,false);
   book.EnsureRound(101.5,g_t0);   // mức 10 giá: ... 90, 100, 110, 120 ...
   datetime now=g_t0+60;
   Check("Mua R=10: bỏ mức 110 (0.83R), lấy 120",Near(book.HtfTarget(1,101.5,101.6,0.1,10.0,now),120) &&
         Near(book.NearestAhead(1,101.5,true,now),110),DoubleToString(book.HtfTarget(1,101.5,101.6,0.1,10.0,now),2));
   Check("Mua R=5: mức 110 (1.66R) đủ xa, giữ",Near(book.HtfTarget(1,101.5,101.6,0.1,5.0,now),110));
   Check("Bán R=2: bỏ mức 100 (0.65R), lấy 90",Near(book.HtfTarget(-1,101.5,101.6,0.1,2.0,now),90),
         DoubleToString(book.HtfTarget(-1,101.5,101.6,0.1,2.0,now),2));
  }

// Đích DOL: bỏ đỉnh râu chưa bị quét cách giá vào dưới 1R (SPEC 23.4), lấy đỉnh kế tiếp.
void TestDolTarget()
  {
   ScpSeries s; s.Init(SCP_TF_M15);
   SigLevelBook book; book.Init(0.01,1,false);
   long seen=0;
   Base(s,book,seen,20);
   Feed(s,book,seen,SIG_M15,Bar(20,900,100,106,99.8,101));          // đỉnh cao H=106
   Feed(s,book,seen,SIG_M15,Bar(21,900,101,101.1,100.2,100.3));
   for(int i=22;i<28;i++) Feed(s,book,seen,SIG_M15,Bar(i,900,100,100.5,99.5,100));
   int next=BuildPivotHigh(s,book,seen,28);                          // đỉnh thấp H=102
   datetime now=g_t0+(datetime)(next*900)+60;
   double d5=book.DolTarget(1,100.3,100.4,0.1,5.0,now);
   Check("DOL mua R=5: bỏ đỉnh 102 (0.3R), lấy đỉnh 106",Near(d5,106) && Near(book.NearestDol(1,100.3,now),102),
         DoubleToString(d5,2)+" gần nhất="+DoubleToString(book.NearestDol(1,100.3,now),2));
   Check("DOL mua R=1: đỉnh 102 (1.5R) đủ xa, giữ",Near(book.DolTarget(1,100.3,100.4,0.1,1.0,now),102));
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

// Sức mạnh cản (SPEC 24.1): đỉnh có nến động lực giảm phá đáy trước đó; cản giả chép số; bản đổi vai ghi thân nến phá.
void TestStrength()
  {
   ScpSeries s; s.Init(SCP_TF_M15);
   SigLevelBook book; book.Init(0.01,7,true);
   long seen=0;
   Base(s,book,seen,20);
   Feed(s,book,seen,SIG_M15,Bar(20,900,100,100.2,98.5,99.8));       // đáy 98.5
   for(int i=21;i<27;i++) Feed(s,book,seen,SIG_M15,Bar(i,900,100,100.5,99.5,100));
   Feed(s,book,seen,SIG_M15,Bar(27,900,100,102,99.8,101));          // đỉnh 102, vùng [101, 102]
   Feed(s,book,seen,SIG_M15,Bar(28,900,101,101.1,98.0,98.2));       // nến động lực giảm, đóng dưới đáy 98.5
   Feed(s,book,seen,SIG_M15,Bar(29,900,98.2,98.6,97.9,98.3));
   Feed(s,book,seen,SIG_M15,Bar(30,900,98.3,98.6,97.9,98.3));       // xác nhận đỉnh
   SigLevel z, g;
   ZeroMemory(z); ZeroMemory(g);
   int ip=-1, ig=-1;
   for(int i=0;i<book.Count();i++)
     {
      SigLevel q;
      if(!book.Get(i,q) || q.type!=SIG_LV_PIVOT || q.flip!=0 || q.role!=-1) continue;
      if(!q.fake) { ip=i; z=q; } else { ig=i; g=q; }
     }
   Check("Sức mạnh: có cản đỉnh thật và cản giả",ip>=0 && ig>=0);
   if(ip<0 || ig<0) return;
   Check("Lực bật >= 2 ATR, thân động lực >= 1,5 ATR",z.disp>=2.0 && z.body_max>=1.5,
         "bật="+DoubleToString(z.disp,2)+" thân="+DoubleToString(z.body_max,2));
   Check("Phá cấu trúc: đóng dưới đáy trước đó",z.bos>=1,"bos="+(string)z.bos);
   Check("Độ lớn đỉnh: cao nhất 27 nến bên trái",z.rank==27,"rank="+(string)z.rank);
   Check("Cản giả chép sức mạnh của cản thật lúc tạo",g.disp==z.disp && g.body_max==z.body_max && g.bos==z.bos && g.rank==z.rank);
   double d0=z.disp;
   Feed(s,book,seen,SIG_M15,Bar(31,900,98.3,98.4,96.0,96.2));       // nến thứ 4 sau gốc: bật thêm
   book.Get(ip,z); book.Get(ig,g);
   Check("Lực bật cập nhật trong 5 nến sau gốc, cản giả chép theo",z.disp>d0 && g.disp==z.disp,
         DoubleToString(d0,2)+" → "+DoubleToString(z.disp,2)+" giả="+DoubleToString(g.disp,2));
   Feed(s,book,seen,SIG_M15,Bar(32,900,96.2,103,96.1,102.8));       // nến động lực tăng đóng trên đỉnh: đổi vai
   SigLevel f;
   ZeroMemory(f);
   int iflip=-1;
   for(int i=0;i<book.Count();i++) { SigLevel q; if(book.Get(i,q) && !q.fake && q.type==SIG_LV_PIVOT && q.flip==1 && q.parent==z.id) { iflip=i; f=q; } }
   Check("Bản đổi vai ghi thân nến phá >= 1,5 ATR",iflip>=0 && f.brk_body>=1.5,iflip>=0 ? DoubleToString(f.brk_body,2) : "không có");
  }

// Hai cản chồng nhau phản ứng cùng nến: chỉ giữ một tín hiệu vào thị trường, của cản khung lớn hơn (SPEC 24.2).
void TestMerge()
  {
   SigLevelBook book; book.Init(0.01,1,false);
   ScpSeries m1; m1.Init(SCP_TF_M1);
   ScpSeries m5; m5.Init(SCP_TF_M5);
   for(int i=0;i<20;i++) { m1.PushBar(Bar(i,60,101.5,102,101,101.5)); m5.PushBar(Bar(i,300,101.5,102,101,101.5)); }
   book.EnsureRound(101.5,g_t0);                                     // số tròn $100 (bậc 3)
   book.AddPeriodExtremes(SIG_LV_PD,Bar(-1,86400,105,110,99.95,106),5.0,101.5); // đáy ngày trước 99.95 (bậc 2)
   int near[]; int nn=book.Near(101.5,5.0,g_t0+1200,near);
   SigDetector det; det.Init(3);
   m1.PushBar(Bar(20,60,101.5,102,101,101.5));
   det.OnEntryBarClosed(0,GetPointer(m1),book,near,nn,0.01);
   det.OnTick(book,near,nn,99.98,g_t0+(datetime)(21*60+10),GetPointer(m1),GetPointer(m5),0.01,false,true,false);
   SigSignal sg[];
   det.Take(sg);                                                     // bỏ lệnh chờ trên giấy lúc chạm
   m1.PushBar(Bar(21,60,100.5,100.65,99.9,100.6));
   det.OnEntryBarClosed(0,GetPointer(m1),book,near,nn,0.01);
   int n=det.Take(sg), mk=0, kept=-1;
   for(int i=0;i<n;i++) if(sg[i].reaction!=SCP_RE_NONE) { mk++; kept=i; }
   Check("Gộp tín hiệu: 2 cản chồng nhau chỉ còn 1 tín hiệu, của cản bậc cao hơn (số tròn $100)",
         mk==1 && sg[kept].merged==1 && sg[kept].group==SIG_G_R100 && det.Merged()==1,
         "tín hiệu="+(string)mk+(kept>=0?" gộp="+(string)sg[kept].merged+" nhóm="+SigGroupName(sg[kept].group):""));
  }

// Phản ứng tại cản (SPEC 24.3): không tính đỉnh nến M1 lúc chạm; bật 2,6 ATR rồi bị phá.
void TestProbe()
  {
   SigProbeBook pb; pb.Init();
   SigTouch t;
   ZeroMemory(t);
   t.level_id=1; t.time=g_t0+30; t.dir=1; t.near=100; t.far=99; t.eps=0.05; t.group=3; t.type=SIG_LV_PIVOT;
   t.atr_src=2.0; t.disp=-1; t.body_max=-1; t.bos=-1; t.rank=-1;
   pb.Open(t,100.0,1.0);
   pb.OnTick(100.5);
   pb.OnM1Close(Bar(0,60,104,105,99.8,100.4));                      // nến lúc chạm: đỉnh 105 có trước lúc chạm, không tính
   pb.OnM1Close(Bar(1,60,100.4,102.6,100.2,102.0));                 // bật 2,6
   pb.OnM5Close(Bar(1,300,102,102.1,98.5,98.6),0.1);                // đóng dưới 99 - 0.1: bị phá
   SigProbeAcc a;
   bool ok=pb.Acc("tat_ca",a);
   Check("Phản ứng tại cản: bật >= 2 ATR, chưa tới 4, không tính nến lúc chạm, bị phá",
         ok && a.n[0]==1 && a.hit[0][1]==1 && a.hit[0][2]==0 && a.brk[0]==1 && pb.OpenCount()==0,
         ok ? "n="+(string)a.n[0]+" >=2:"+(string)a.hit[0][1]+" >=4:"+(string)a.hit[0][2]+" phá:"+(string)a.brk[0] : "không có nhóm");
  }

// Vùng Z của 411 (SPEC 23.2 L5): hình M: A 97, đỉnh 1 104, B 99 (> A), đỉnh 2 104.2; Z = nến đầu có đáy thấp hơn đáy nến trước.
// Chỉ dùng được sau khi phá B rồi A (râu cũng tính).
void TestZone()
  {
   ScpSeries s; s.Init(SCP_TF_M15);
   SigLevelBook book; book.Init(0.01,1,false);
   long seen=0;
   Base(s,book,seen,20);
   double bars[][4]={{100,100.2,97.0,99.8},{100,101,99.6,100.8},{100.8,101.5,100.2,101.2},{101.2,102,100.8,101.8},
                     {101.8,104,101.5,103.5},{103.5,103.6,102,102.2},{102.2,102.4,100.8,101},{101,101.2,99.9,100.2},
                     {100.2,100.4,99.0,99.8},{99.8,101,99.5,100.8},{100.8,102,100.5,101.8},{101.8,103,101.4,102.8},
                     {102.8,104.2,102.5,103.8},{103.8,104.0,102.0,102.3},{102.3,102.5,101.0,101.2},{101.2,101.4,100.2,100.4}};
   for(int i=0;i<16;i++) Feed(s,book,seen,SIG_M15,Bar(20+i,900,bars[i][0],bars[i][1],bars[i][2],bars[i][3]));
   int iz=-1;
   SigLevel z;
   ZeroMemory(z);
   for(int i=0;i<book.Count();i++) { SigLevel q; if(book.Get(i,q) && q.type==SIG_LV_Z && q.role==-1 && Near(q.bottom,102.0)) { iz=i; z=q; } }
   Check("Vùng Z: có vùng bán [102, 104] (cả nến Z), đang chờ phá B rồi A",iz>=0 && Near(z.top,104.0) && z.pend &&
         !book.Usable(iz,g_t0+(datetime)(40*900)),iz>=0 ? DoubleToString(z.bottom,2)+"-"+DoubleToString(z.top,2) : "không có");
   if(iz<0) return;
   Feed(s,book,seen,SIG_M15,Bar(36,900,100.4,100.5,98.8,99.0));    // phá B 99
   book.Get(iz,z);
   bool still=z.pend;
   Feed(s,book,seen,SIG_M15,Bar(37,900,99.0,99.2,96.8,97.0));      // phá A 97
   book.Get(iz,z);
   Check("Vùng Z: phá B chưa đủ; phá tiếp A thì dùng được từ lúc nến đó đóng",still && !z.pend && z.known_at==g_t0+(datetime)(38*900),
         "chờ sau B="+(string)still+" biết="+TimeToString(z.known_at));
  }

// Unicorn (SPEC 23.3 K3), mua trên M5: hai đỉnh bằng nhau 106/106.05 (DOL) → đáy 97.5 quét đáy 98 → nến breaker tăng [99.8, 102]
// → nến dịch chuyển đóng 103.3 trên breaker → FVG [99.0, 102.6] chồng breaker. Vùng = hợp [99.0, 102.6].
void TestUnicorn()
  {
   ScpSeries s; s.Init(SCP_TF_M5);
   SigLevelBook book; book.Init(0.01,1,false);
   long seen=0;
   for(int i=0;i<20;i++) Feed(s,book,seen,SIG_M5,Bar(i,300,100,100.5,99.5,100));
   double bars[][4]={{100,106,99.8,100.5},{100,100.5,99.5,100},{100,100.5,99.5,100},{100,100.5,99.5,100},{100,100.5,99.5,100},
                     {100,106.05,99.8,100.4},{100,100.5,99.5,100},{100,100.5,99.5,100},{100,100.3,98.0,99.9},{100,100.5,99.5,100},
                     {100,100.5,99.5,100},{100,102,99.8,101.8},{101.8,101.9,100.5,100.7},{100.7,100.8,99.0,99.2},{99.2,99.4,97.5,97.8},
                     {97.8,99.0,97.7,98.9},{98.9,103.5,98.8,103.3},{103.3,104,102.6,103.8}};
   for(int i=0;i<18;i++) Feed(s,book,seen,SIG_M5,Bar(20+i,300,bars[i][0],bars[i][1],bars[i][2],bars[i][3]));
   SigLevel u;
   ZeroMemory(u);
   int iu=-1;
   for(int i=0;i<book.Count();i++) { SigLevel q; if(book.Get(i,q) && q.type==SIG_LV_UNI) { iu=i; u=q; } }
   Check("Unicorn: vùng mua [99.0, 102.6] = breaker ∪ FVG, biết lúc nến FVG thứ 3 đóng",
         iu>=0 && u.role==1 && Near(u.bottom,99.0) && Near(u.top,102.6) && u.known_at==g_t0+(datetime)(38*300),
         iu>=0 ? DoubleToString(u.bottom,2)+"-"+DoubleToString(u.top,2)+" biết="+TimeToString(u.known_at) : "không có");
   Check("Unicorn: dừng lỗ thân 97.8 / râu 97.5 của nhánh thao túng, đích DOL 106.05, hạn 24 nến",
         iu>=0 && Near(u.sl_body,97.8) && Near(u.sl_wick,97.5) && Near(u.dol,106.05) && u.max_age==SIG_UNI_AGE,
         iu>=0 ? DoubleToString(u.sl_body,2)+"/"+DoubleToString(u.sl_wick,2)+" DOL="+DoubleToString(u.dol,2) : "");
  }

void OnStart()
  {
   TestLevels();
   TestFlipChain();
   TestFlipOscillation();
   TestAgeAfterFull();
   TestGapDoji();
   TestTracker();
   TestHtfTarget();
   TestDolTarget();
   TestStrength();
   TestMerge();
   TestProbe();
   TestZone();
   TestUnicorn();
   TestDetector();
   TestPaperLimit();
   Print("[SIG_VERIFY] TOTAL ",g_pass+g_fail," | PASS ",g_pass," | FAIL ",g_fail);
   if(InpCloseTerminal) TerminalClose(0);
  }
