// Cản khung lớn cho PhanUngLab (SPEC §25): trên nến đã đóng của M15, H1, H4, D1 tìm FVG, OB (lớp nội bộ), SNR (phần râu nến pivot),
// MSNR (nến khung đóng qua thì lật vai), và đỉnh/đáy ngày trước (PDH/PDL), tuần trước (PWH/PWL). Nến khung lớn chỉ dùng khi
// giờ mở + độ dài khung ≤ giờ mở nến khung vào lệnh; nến D1 Chủ nhật/Thứ Bảy gộp vào ngày giao dịch kế tiếp. Vùng dùng được từ nến
// khung vào lệnh đầu tiên mở ≥ lúc biết, và chỉ nhận chạm sau khi có nến mở đúng phía (25.1). Hỏng, lật, hết tuổi xét bằng nến của
// chính khung vùng. Chạm và phản ứng R1–R3 xét trên nến khung vào lệnh như SmcZones; R4 qua nến M1. Gắn nhãn "trùng" (25.5) cho
// vùng khung vào lệnh qua ISmcTagger. Chỉ tìm và ghi sổ, không vào lệnh.
#ifndef BOTVANG_HTFZONES_MQH
#define BOTVANG_HTFZONES_MQH

#include "SmcDetect.mqh"
#include "SmcZones.mqh"

#define HZ_FVG      0
#define HZ_OB       1
#define HZ_SNR      2
#define HZ_MSNR     3
#define HZ_DW       4   // đỉnh/đáy ngày trước, tuần trước
#define HZ_COUNT    5

#define HTF_COUNT   4   // khung M15, H1, H4, D1 (chỉ số 0..3)
#define HT_D1       3
#define HF_DAY      4   // khung ghi của PDH/PDL
#define HF_WEEK     5   // khung ghi của PWH/PWL
#define HF_COUNT    6

// lý do hết vùng
#define HD_ALIVE    0
#define HD_CLOSE    1   // nến khung vùng đóng qua mép xa
#define HD_AGE      2   // hết tuổi
#define HD_MERGED   3   // gộp vào vùng khung lớn hơn cùng giá (25.4)
#define HD_REPLACED 4   // ngày/tuần mới thay mức

string HtfTfName[HF_COUNT] = {"M15", "H1", "H4", "D1", "Ngay", "Tuan"};
string HtfTypeName[HZ_COUNT] = {"FVG", "OB", "SNR", "MSNR", "Ngay/Tuan"};

// Vùng đã sinh một lệnh: khung (−1: khung vào lệnh; 0..5 như HtfTfName), loại, mã, lúc biết, lúc có nến mở đúng phía (khung lớn),
// giờ mở nến chạm đầu, nhãn trùng (vùng khung vào lệnh), cực trị ngày/tuần in gần giờ nghỉ (1 có, 0 không, −1 không biết / không phải)
struct ZoneRef
  {
   int               tf;
   int               type;
   int               id;
   datetime          known;
   datetime          armed;
   datetime          touch;
   double            top, bottom;
   SmcTag            tag;
   int               nearBreak;
  };

struct HtfZone
  {
   SmcZone           s;          // type = HZ_*; k0: −1 chưa chạm, −2 đã chạm lúc nạp lịch sử; s.born không dùng
   int               tf;
   int               bornHtf;    // chỉ số nến khung vùng lúc tạo (tuổi)
   datetime          known;
   datetime          armedAt;    // 0: chưa có nến mở đúng phía
   bool              armChecked;
   int               nearBreak;
   bool              dead;
  };

// Vùng khung lớn vừa được một nến M1 chạm lần đầu (R4)
struct HtfHit
  {
   int               type;
   int               dir;
   double            top, bottom;
   ZoneRef           ref;
  };

// Sổ mỗi vùng (vung_htf.csv), chỉ số = mã vùng
struct HtfLog
  {
   int               tf, type, dir0;
   double            top, bottom;
   datetime          origin, known, armedAt, touch, end;
   int               endReason, mergedInto, flips, nearBreak;
   bool              warm;       // tạo lúc nạp lịch sử trước nến khung vào lệnh đầu tiên
  };

// Tuần giao dịch của lúc t: mã = số ngày (từ 1970) của thứ Hai; CN, T7 thuộc tuần của ngày giao dịch kế tiếp (tính theo lịch, không theo t/604800)
int HtfWeekKey(datetime t)
  {
   MqlDateTime d;
   TimeToStruct(t, d);
   int day = (int)(t / 86400), dow = d.day_of_week;
   if(dow == 0)
     {
      day += 1;
      dow = 1;
     }
   else
      if(dow == 6)
        {
         day += 2;
         dow = 1;
        }
   return day - (dow - 1);
  }

// Đỉnh/đáy pivot N/N ở nến p (≥ N nến trước, > N nến sau), như SmcZones với N là tham số
bool HtfPivotHigh(const CSmcBars &B, int p, int N)
  {
   for(int k = 1; k <= N; k++)
      if(B.b[p].h < B.b[p - k].h || B.b[p].h <= B.b[p + k].h)
         return false;
   return true;
  }
bool HtfPivotLow(const CSmcBars &B, int p, int N)
  {
   for(int k = 1; k <= N; k++)
      if(B.b[p].l > B.b[p - k].l || B.b[p].l >= B.b[p + k].l)
         return false;
   return true;
  }

// Mốc ngày giao dịch: 00:00 thứ Ba .. thứ Bảy (lúc nến D1 gộp đóng; 00:00 CN, T2 không phải mốc vì nến CN/T7 gộp vào T2).
// Mốc gần nhất ≤ t (up = false) hoặc ≥ t (up = true). Mọi nến M15, H1, H4 và nến D1 gộp đều đóng đúng ở mốc, không nến nào vắt qua.
datetime HtfDayEdge(datetime t, bool up)
  {
   datetime d = (datetime)((long)t / 86400 * 86400);
   if(up && d < t)
      d += 86400;
   while(true)
     {
      MqlDateTime s;
      TimeToStruct(d, s);
      if(s.day_of_week >= 2)
         return d;
      d += up ? 86400 : -86400;
     }
  }

// Chỉ số nến đầu tiên có giờ mở ≥ t (E.n nếu không có)
int HtfLowerBound(const CSmcBars &E, datetime t)
  {
   int lo = 0, hi = E.n;
   while(lo < hi)
     {
      int mid = (lo + hi) / 2;
      if(E.b[mid].t < t)
         lo = mid + 1;
      else
         hi = mid;
     }
   return lo;
  }

// Nến đã đóng của một khung lớn và cấu trúc, FVG của nó
class CHtfTf
  {
public:
   ENUM_TIMEFRAMES   tf;
   int               N;
   int               P;          // độ dài khung (giây); D1: 86400
   CSmcBars          B;          // nến đã đóng (D1: đã gộp nến CN/T7)
   CSmcStructure     st;
   CSmcFvgs          fvg;
   datetime          start[];    // giờ bắt đầu thật của nến (nến D1 gộp: giờ nến CN)
   datetime          lastOpen;   // giờ mở nến gốc cuối cùng đã nhận (kể cả nến CN đang giữ)
   bool              hasHeld;
   MqlRates          held;       // nến CN/T7 đang giữ chờ gộp
   int               nHeld;
   int               warmGot, drained;
   datetime          warmFirst;
   MqlRates          q[];        // nến đã đóng chờ nạp
   int               nq;
   bool              fetched;
   MqlRates          w[];        // nến lấy lúc nạp lịch sử (theo số nến); wpos = nến kế tiếp chưa xếp hàng
   int               wpos;

   void              Init(ENUM_TIMEFRAMES t, int n)
     {
      tf = t;
      N = n;
      P = PeriodSeconds(t);
      B.Init();
      st.Init(n);
      fvg.Init();
      ArrayResize(start, 0, 4096);
      lastOpen = 0;
      hasHeld = false;
      nHeld = 0;
      warmGot = 0;
      drained = 0;
      warmFirst = 0;
      nq = 0;
      fetched = false;
      ArrayResize(w, 0);
      wpos = 0;
     }

   // Nạp lịch sử: xếp hàng các nến trong w có lúc đóng ≤ te (chưa xếp)
   void              QueueWarm(datetime te)
     {
      while(wpos < ArraySize(w) && w[wpos].time + P <= te)
         Queue(w[wpos++]);
     }

   void              Queue(const MqlRates &r)
     {
      if(nq >= ArraySize(q))
         ArrayResize(q, 2 * nq + 64);
      q[nq++] = r;
     }
  };

class CHtfZones : public ISmcTagger
  {
private:
   int               m_pwKey;
   int               m_entryP;   // độ dài nến khung vào lệnh (giây)
   datetime          m_fine[HT_D1];   // lúc nạp lịch sử: từ mốc ngày này khung M15 / H1 / H4 đã có lịch sử (dùng xét chạm thay khung lớn hơn)
   CSmcBars          m_pre;      // nến khung vào lệnh từ mốc nạp lịch sử tới nến khung vào lệnh nạp lịch sử đầu tiên (chỉ cho vùng khung lớn)

   // Lúc nạp lịch sử: khung nhỏ nhất đã có lịch sử ở lúc t (xét đúng phía/chạm trên nến của khung này)
   int               FineTf(datetime t) const
     {
      for(int k = 0; k < HT_D1; k++)
         if(m_fine[k] <= t)
            return k;
      return HT_D1;
     }

   void              Kill(int k, int reason, datetime when)
     {
      z[k].dead = true;
      int id = z[k].s.id;
      lg[id].end = when;
      lg[id].endReason = reason;
     }

   int               NewZone(int tf, int type, int dir, double top, double bottom, int bornHtf, datetime origin, datetime known, bool warm)
     {
      if(n >= ArraySize(z))
         ArrayResize(z, 2 * n + 256);
      int id = nLog;
      if(nLog >= ArraySize(lg))
         ArrayResize(lg, 2 * nLog + 1024);
      nLog++;
      lg[id].tf = tf;
      lg[id].type = type;
      lg[id].dir0 = dir;
      lg[id].top = top;
      lg[id].bottom = bottom;
      lg[id].origin = origin;
      lg[id].known = known;
      lg[id].armedAt = 0;
      lg[id].touch = 0;
      lg[id].end = 0;
      lg[id].endReason = HD_ALIVE;
      lg[id].mergedInto = -1;
      lg[id].flips = 0;
      lg[id].nearBreak = -1;
      lg[id].warm = warm;
      ZeroMemory(z[n]);
      z[n].s.type = type;
      z[n].s.dir = dir;
      z[n].s.top = top;
      z[n].s.bottom = bottom;
      z[n].s.born = -1;
      z[n].s.k0 = -1;
      z[n].s.fired = 0;
      z[n].s.m1Touched = false;
      z[n].s.id = id;
      z[n].s.tag.ovl = -1;
      z[n].tf = tf;
      z[n].bornHtf = bornHtf;
      z[n].known = known;
      z[n].armedAt = 0;
      z[n].armChecked = false;
      z[n].nearBreak = -1;
      z[n].dead = false;
      cCreated[tf][type]++;
      return n++;
     }

   // 25.4: mức SNR/MSNR khung k vừa tạo (chỉ số zi) đúng bằng giá một mức còn sống cùng loại, cùng vai của khung nhỏ hơn:
   // bỏ mức khung nhỏ, mức mới nhận lần chạm sớm nhất (k0, fired) và dấu đã chạm M1
   void              Dedup(int zi)
     {
      int type = z[zi].s.type, dir = z[zi].s.dir, tf = z[zi].tf;
      double price = type == HZ_SNR && dir < 0 ? z[zi].s.top : z[zi].s.bottom;
      int bestK0 = -1, bestFired = 0;
      datetime armed = 0;
      datetime touch = 0;
      bool m1 = false;
      for(int k = 0; k < n; k++)
        {
         if(k == zi || z[k].dead || z[k].s.type != type || z[k].s.dir != dir || z[k].tf >= tf)
            continue;
         double p = type == HZ_SNR && dir < 0 ? z[k].s.top : z[k].s.bottom;
         if(MathAbs(p - price) > _Point / 2.0)
            continue;
         m1 = m1 || z[k].s.m1Touched;
         int k0 = z[k].s.k0;
         if(k0 != -1 && (bestK0 == -1 || k0 < bestK0))
           {
            bestK0 = k0;
            bestFired = z[k].s.fired;
            touch = lg[z[k].s.id].touch;
            armed = z[k].armedAt;
           }
         Kill(k, HD_MERGED, z[zi].known);
         lg[z[k].s.id].mergedInto = z[zi].s.id;
         cMerged[z[k].tf][type]++;
        }
      if(bestK0 != -1)
        {
         z[zi].s.k0 = bestK0;
         z[zi].s.fired = bestFired;
         lg[z[zi].s.id].touch = touch;
         z[zi].armedAt = armed;   // mức nhỏ đã đúng phía trước lần chạm đó
         lg[z[zi].s.id].armedAt = armed;
        }
      if(m1)
         z[zi].s.m1Touched = true;
     }

   // Nạp lịch sử trước mốc (chưa có nến khung vào lệnh): nến j của khung k xét các vùng đã biết trước nến j mà khung k là khung nhỏ
   // nhất có lịch sử lúc đó, không nhỏ hơn khung của vùng (mức ngày/tuần như D1). Nến j mở đúng phía thì đúng phía, rồi râu nến j chạm
   // thì coi như đã chạm (k0 = −2). Nhờ xét trên khung nhỏ nhất có được, vùng vào đúng phía rồi bị chạm trong cùng một nến khung lớn
   // vẫn được ghi (trừ khi xảy ra trong cùng một nến của khung nhỏ nhất đó).
   void              WarmTouch(int k, int j)
     {
      SmcBar b = T[k].B.b[j];
      datetime st = T[k].start[j];
      int fine = FineTf(st);
      for(int x = 0; x < n; x++)
        {
         if(z[x].dead || z[x].s.k0 != -1 || z[x].known > st || MathMin(MathMin(z[x].tf, HT_D1), fine) != k)
            continue;
         if(z[x].armedAt == 0)
           {
            bool ok = z[x].s.dir > 0 ? b.o > z[x].s.top : b.o < z[x].s.bottom;
            if(!z[x].armChecked && !ok)
               cUnarmed[z[x].tf][z[x].s.type]++;
            z[x].armChecked = true;
            if(!ok)
               continue;
            z[x].armedAt = st;
            lg[z[x].s.id].armedAt = st;
           }
         if(ZTouch(z[x].s.dir, z[x].s.top, z[x].s.bottom, b))
           {
            z[x].s.k0 = -2;
            z[x].s.fired = 7;
            z[x].s.m1Touched = true;
            lg[z[x].s.id].touch = st;
            cWarmTouch[z[x].tf][z[x].s.type]++;
           }
        }
     }

   // Nến j của khung k vừa đóng: hết tuổi (tuổi của nến khung kế tiếp, như SmcZones xét lúc chạm), hỏng khi đóng qua mép xa, MSNR lật vai
   void              CloseChecks(int k, int j, datetime closeT)
     {
      double c = T[k].B.b[j].c;
      for(int x = 0; x < n; x++)
        {
         if(z[x].dead || z[x].tf != k || z[x].bornHtf >= j)
            continue;
         int type = z[x].s.type, age = j + 1 - z[x].bornHtf;
         if((type == HZ_MSNR && age >= 100) || (type == HZ_OB && age > 300) || ((type == HZ_FVG || type == HZ_SNR) && age > 500))
           {
            Kill(x, HD_AGE, closeT);
            cAge[k][type]++;
            continue;
           }
         if(!(z[x].s.dir > 0 ? c < z[x].s.bottom : c > z[x].s.top))
            continue;
         if(type != HZ_MSNR)
           {
            Kill(x, HD_CLOSE, closeT);
            cClose[k][type]++;
            continue;
           }
         // MSNR: lật vai, coi như mức mới chưa chạm, phải có nến mở đúng phía mới nhận chạm; tuổi vẫn tính từ lúc tạo.
         // Sổ vung_htf.csv chỉ ghi lúc đúng phía / chạm đầu của vai hiện tại
         z[x].s.dir = -z[x].s.dir;
         z[x].s.k0 = -1;
         z[x].s.fired = 0;
         z[x].s.m1Touched = false;
         z[x].armedAt = 0;
         lg[z[x].s.id].armedAt = 0;
         lg[z[x].s.id].touch = 0;
         lg[z[x].s.id].flips++;
         cFlip[k]++;
        }
     }

   // Cực trị level (đỉnh khi isHigh) của đoạn [from, to) có in trong 15 phút sau lúc mở lại sau khoảng nghỉ ≥ 30 phút, hoặc trong
   // 30 phút trước lúc bắt đầu khoảng nghỉ như vậy (theo nến khung vào lệnh E; nextOpen = giờ mở nến sau nến cuối của E).
   // −1: E không phủ đủ đoạn. Kèm kiểm tra cực trị đoạn = cực trị các nến E trong đoạn (ext: 1 khớp, 0 lệch, −1 không xét)
   int               NearBreak(const CSmcBars &E, datetime from, datetime to, datetime nextOpen, double level, bool isHigh, int &ext) const
     {
      ext = -1;
      if(E.n == 0 || E.b[0].t > from)
         return -1;
      int x0 = HtfLowerBound(E, from), e = -1;
      double m = isHigh ? -DBL_MAX : DBL_MAX;
      for(int x = x0; x < E.n && E.b[x].t < to; x++)
        {
         double v = isHigh ? E.b[x].h : E.b[x].l;
         if(e < 0 && v == level)
            e = x;
         m = isHigh ? MathMax(m, v) : MathMin(m, v);
        }
      ext = m == level ? 1 : 0;
      if(e < 0)
         return -1;
      for(int k = e; k > 0 && E.b[e].t - E.b[k].t < 900; k--)
         if(E.b[k].t - (E.b[k - 1].t + m_entryP) >= 1800)
            return 1;
      for(int k = e; k < E.n && E.b[k].t + m_entryP - E.b[e].t <= 1800; k++)
        {
         datetime next = k + 1 < E.n ? E.b[k + 1].t : nextOpen;
         if(next - (E.b[k].t + m_entryP) >= 1800)
            return 1;
        }
      return 0;
     }

   // Tạo cặp mức cao/thấp (ngày hoặc tuần) thay cặp cũ
   void              NewPair(int tf, double hi, double lo, int bornHtf, datetime origin, datetime from, datetime to, datetime known,
                             datetime nextOpen, const CSmcBars &E, bool warm)
     {
      for(int x = 0; x < n; x++)
         if(!z[x].dead && z[x].tf == tf)
           {
            Kill(x, HD_REPLACED, known);
            cReplaced[tf]++;
           }
      int chk = 0, ext;
      for(int s = 0; s < 2; s++)
        {
         bool isHigh = s == 0;
         int zi = NewZone(tf, HZ_DW, isHigh ? -1 : 1, isHigh ? hi : lo, isHigh ? hi : lo, bornHtf, origin, known, warm);
         z[zi].nearBreak = NearBreak(E, from, to, nextOpen, isHigh ? hi : lo, isHigh, ext);
         lg[z[zi].s.id].nearBreak = z[zi].nearBreak;
         if(z[zi].nearBreak == 1)
            cNearBreak[tf - HF_DAY]++;
         if(ext >= 0)
           {
            chk++;
            if(ext == 0)
               extMismatch[tf - HF_DAY]++;
           }
        }
      if(chk == 2)
         extChecked[tf - HF_DAY]++;
     }

   // Nến D1 (đã gộp) j vừa đóng: PDH/PDL mới, dùng từ lúc đóng
   void              RollDay(int j, datetime closeT, datetime te, const CSmcBars &E, bool warm)
     {
      SmcBar b = T[HT_D1].B.b[j];
      NewPair(HF_DAY, b.h, b.l, j, b.t, T[HT_D1].start[j], closeT, closeT, te, E, warm);
     }

   // Tuần giao dịch mới ở lúc t: PWH/PWL = cao nhất / thấp nhất các nến D1 gộp của tuần gần nhất trước đó (so với nến W1 của sàn ở W1Check)
   void              RollWeek(datetime t, datetime te, const CSmcBars &E, bool warm)
     {
      int wk = HtfWeekKey(t);
      if(wk == m_pwKey)
         return;
      m_pwKey = wk;
      int last = T[HT_D1].B.n - 1;
      while(last >= 0 && HtfWeekKey(T[HT_D1].B.b[last].t) >= wk)
         last--;
      if(last < 0)
         return;
      int key0 = HtfWeekKey(T[HT_D1].B.b[last].t), first = last;
      double hi = T[HT_D1].B.b[last].h, lo = T[HT_D1].B.b[last].l;
      while(first > 0 && HtfWeekKey(T[HT_D1].B.b[first - 1].t) == key0)
        {
         first--;
         hi = MathMax(hi, T[HT_D1].B.b[first].h);
         lo = MathMin(lo, T[HT_D1].B.b[first].l);
        }
      NewPair(HF_WEEK, hi, lo, last, T[HT_D1].B.b[first].t, T[HT_D1].start[first], (datetime)(T[HT_D1].B.b[last].t + 86400), t, te, E, warm);
     }

   // Nhận một nến gốc đã đóng r của khung k (warm: đoạn nạp lịch sử trước nến khung vào lệnh đầu tiên)
   void              Ingest(int k, const MqlRates &r, datetime te, const CSmcBars &E, bool warm)
     {
      T[k].lastOpen = r.time;
      if(r.time + T[k].P > te || r.time >= iTime(_Symbol, T[k].tf, 0))
         ingestEarly++;   // tự kiểm tra: nến chưa đóng (không được xảy ra)
      MqlRates bar = r;
      datetime st = r.time;
      if(k == HT_D1)
        {
         MqlDateTime d;
         TimeToStruct(r.time, d);
         if(d.day_of_week == 0 || d.day_of_week == 6)
           {
            if(!T[k].hasHeld)
               T[k].held = r;
            else
              {
               T[k].held.high = MathMax(T[k].held.high, r.high);
               T[k].held.low = MathMin(T[k].held.low, r.low);
               T[k].held.close = r.close;
              }
            T[k].hasHeld = true;
            T[k].nHeld++;
            return;
           }
         if(T[k].hasHeld)
           {
            bar.open = T[k].held.open;
            bar.high = MathMax(T[k].held.high, r.high);
            bar.low = MathMin(T[k].held.low, r.low);
            st = T[k].held.time;
            T[k].hasHeld = false;
           }
        }
      int j = T[k].B.Add(bar);
      ArrayResize(T[k].start, j + 1, 4096);
      T[k].start[j] = st;
      datetime closeT = bar.time + T[k].P;
      SmcBreak ev;
      T[k].st.OnBar(T[k].B, j, ev);
      T[k].fvg.OnBar(T[k].B, j);
      if(warm)
        {
         T[k].drained++;
         if(k == FineTf(st))
            RollWeek(st, te, E, true);   // tuần mới từ nến đầu tuần của khung đang dùng xét chạm (như lúc chạy: nến đầu tuần)
         WarmTouch(k, j);
        }
      CloseChecks(k, j, closeT);
      if(T[k].B.Ready())
        {
         for(int x = T[k].fvg.n - 1; x >= 0 && T[k].fvg.f[x].i == j; x--)
            NewZone(k, HZ_FVG, T[k].fvg.f[x].dir, T[k].fvg.f[x].top, T[k].fvg.f[x].bottom, j, T[k].B.b[j - 2].t, closeT, warm);
         if(ev.valid && !ev.initial && ev.ob)
            NewZone(k, HZ_OB, ev.dir, ev.obHi, ev.obLo, j, T[k].B.b[ev.leg].t, closeT, warm);
         int N = T[k].N, p = j - N;
         if(p - N >= 0)
           {
            SmcBar pb = T[k].B.b[p];
            if(HtfPivotHigh(T[k].B, p, N))
               Dedup(NewZone(k, HZ_SNR, -1, pb.h, MathMax(pb.o, pb.c), j, pb.t, closeT, warm));
            if(HtfPivotLow(T[k].B, p, N))
               Dedup(NewZone(k, HZ_SNR, 1, MathMin(pb.o, pb.c), pb.l, j, pb.t, closeT, warm));
           }
         if(j >= 1)
           {
            SmcBar a = T[k].B.b[j - 1], b = T[k].B.b[j];
            if(a.c > a.o && b.c < b.o)
               Dedup(NewZone(k, HZ_MSNR, -1, a.c, a.c, j, a.t, closeT, warm));
            else
               if(a.c < a.o && b.c > b.o)
                  Dedup(NewZone(k, HZ_MSNR, 1, a.c, a.c, j, a.t, closeT, warm));
           }
        }
      if(k == HT_D1)
         RollDay(j, closeT, te, E, warm);
     }

   // Nạp các nến đang chờ của 4 khung theo lúc đóng, cùng lúc thì M15 → H1 → H4 → D1 (để gộp mức đi lên khung lớn)
   void              IngestQueued(datetime te, const CSmcBars &E, bool warm)
     {
      int pos[HTF_COUNT];
      ArrayInitialize(pos, 0);
      while(true)
        {
         int best = -1;
         datetime bc = 0;
         for(int k = 0; k < HTF_COUNT; k++)
            if(pos[k] < T[k].nq)
              {
               datetime c = T[k].q[pos[k]].time + T[k].P;
               if(best < 0 || c < bc)
                 {
                  best = k;
                  bc = c;
                 }
              }
         if(best < 0)
            break;
         Ingest(best, T[best].q[pos[best]], te, E, warm);
         pos[best]++;
        }
      for(int k = 0; k < HTF_COUNT; k++)
         T[k].nq = 0;
     }

   void              Compact(void)
     {
      int keep = 0;
      for(int k = 0; k < n; k++)
         if(!z[k].dead)
            z[keep++] = z[k];
      n = keep;
     }

   void              KeepRep(int k, int r, int side, datetime touch)
     {
      int ri = (z[k].s.type * 3 + r) * 2 + (side == ZS_BUY ? 0 : 1);
      if((react[z[k].s.type * 3 + r] & side) != 0 && rep[ri].tf >= z[k].tf)
         return;   // giữ vùng khung lớn nhất làm đại diện
      rep[ri] = RefOf(k, touch);
     }

public:
   CHtfTf            T[HTF_COUNT];
   HtfZone           z[];
   int               n;
   HtfLog            lg[];
   int               nLog;
   // kết quả của nến khung vào lệnh vừa xét (như CSmcZones): mặt nạ ZS_* theo loại vùng; vùng đại diện của mỗi ô và chiều
   int               touched[HZ_COUNT];
   int               react[HZ_COUNT * 3];
   ZoneRef           rep[HZ_COUNT * 3 * 2];
   // thống kê [khung][loại]
   int               cCreated[HF_COUNT][HZ_COUNT], cMerged[HF_COUNT][HZ_COUNT], cClose[HF_COUNT][HZ_COUNT], cAge[HF_COUNT][HZ_COUNT];
   int               cUnarmed[HF_COUNT][HZ_COUNT], cTouch[HF_COUNT][HZ_COUNT], cWarmTouch[HF_COUNT][HZ_COUNT];
   int               cFlip[HF_COUNT], cReplaced[HF_COUNT];
   int               cNearBreak[2], extChecked[2], extMismatch[2];   // [ngày, tuần]
   int               cTag, cTagOvl, cTagMsnr;
   // tự kiểm tra (phải bằng 0, trừ PW khác W1 phải giải thích)
   int               useEarly, ingestEarly, late, pwChecked, pwMismatch, w1Alt;
   int               w1Dow;
   datetime          cut;        // mốc nạp lịch sử (Warm)
   int               preGot;     // số nến khung vào lệnh từ mốc tới nến khung vào lệnh nạp lịch sử đầu tiên

   void              Init(void)
     {
      T[0].Init(PERIOD_M15, 5);
      T[1].Init(PERIOD_H1, 5);
      T[2].Init(PERIOD_H4, 3);
      T[3].Init(PERIOD_D1, 3);
      n = 0;
      nLog = 0;
      ArrayResize(z, 0);
      ArrayResize(lg, 0);
      m_pwKey = -1;
      m_entryP = PeriodSeconds(_Period);
      ArrayInitialize(cCreated, 0);
      ArrayInitialize(cMerged, 0);
      ArrayInitialize(cClose, 0);
      ArrayInitialize(cAge, 0);
      ArrayInitialize(cUnarmed, 0);
      ArrayInitialize(cTouch, 0);
      ArrayInitialize(cWarmTouch, 0);
      ArrayInitialize(cFlip, 0);
      ArrayInitialize(cReplaced, 0);
      ArrayInitialize(cNearBreak, 0);
      ArrayInitialize(extChecked, 0);
      ArrayInitialize(extMismatch, 0);
      cTag = cTagOvl = cTagMsnr = 0;
      useEarly = ingestEarly = late = pwChecked = pwMismatch = w1Alt = 0;
      w1Dow = -1;
      cut = 0;
      preGot = 0;
      for(int k = 0; k < HT_D1; k++)
         m_fine[k] = D'3000.01.01';
      m_pre.Init();
     }

   ZoneRef           RefOf(int k, datetime touch) const
     {
      ZoneRef r;
      ZeroMemory(r);
      r.tf = z[k].tf;
      r.type = z[k].s.type;
      r.id = z[k].s.id;
      r.known = z[k].known;
      r.armed = z[k].armedAt;
      r.touch = touch;
      r.top = z[k].s.top;
      r.bottom = z[k].s.bottom;
      r.tag.ovl = -1;
      r.nearBreak = z[k].nearBreak;
      return r;
     }

   // Nạp lịch sử khung lớn lúc bắt đầu (T0, open0 = giờ mở, giá mở nến khung vào lệnh nạp lịch sử đầu tiên). Mốc = mốc ngày gần nhất
   // ≤ T0 (HtfDayEdge), nên không nến khung lớn nào vắt qua mốc. Nến đóng ≤ mốc: xử lý nhanh (đúng phía/chạm theo nến của khung nhỏ nhất
   // đã có lịch sử, WarmTouch). Từ mốc tới T0: nến khung vào lệnh (m_pre, chỉ cho vùng khung lớn) xét như lúc chạy (OnBar, nạp nến khung
   // lớn đã đóng như Sync nhưng lấy từ nến đã lấy lúc nạp, ArmCheck), kết thúc ở T0. Phần sau nạp dần bằng Sync cùng nến khung vào lệnh nạp
   // lịch sử.
   void              Warm(datetime T0, double open0)
     {
      int want[HTF_COUNT] = {1500, 1000, 700, 600};
      cut = HtfDayEdge(T0, false);
      for(int k = 0; k < HTF_COUNT; k++)
        {
         ArraySetAsSeries(T[k].w, false);
         int got = CopyRates(_Symbol, T[k].tf, 1, want[k], T[k].w);
         T[k].warmGot = got;
         T[k].warmFirst = got > 0 ? T[k].w[0].time : 0;
         if(k < HT_D1)
            m_fine[k] = got > 0 ? HtfDayEdge(T[k].w[0].time, true) : D'3000.01.01';
         T[k].QueueWarm(cut);
        }
      m_pre.Init();
      IngestQueued(cut, m_pre, true);
      MqlRates p[];
      ArraySetAsSeries(p, false);
      int np = T0 > cut ? CopyRates(_Symbol, _Period, cut, (datetime)(T0 - 1), p) : 0;
      preGot = np;
      np = MathMax(np, 0);
      // bước i: nến p[i−1] vừa đóng; nạp nến khung lớn đóng tới giờ mở nến sau (p[i], hoặc T0 ở bước cuối), thay tuần, xét đúng phía bằng giá mở
      for(int i = 0; i <= np; i++)
        {
         if(i > 0)
            OnBar(m_pre, m_pre.Add(p[i - 1]));
         datetime te = i < np ? p[i].time : T0;
         for(int k = 0; k < HTF_COUNT; k++)
            T[k].QueueWarm(te);
         IngestQueued(te, m_pre, false);
         RollWeek(te, te, m_pre, false);
         Compact();
         ArmCheck(i < np ? p[i].open : open0, te);
        }
      for(int k = 0; k < HTF_COUNT; k++)
        {
         if(T[k].lastOpen == 0)
            T[k].lastOpen = T0 - T[k].P;   // không có lịch sử: chỉ nạp nến mới
         ArrayResize(T[k].w, 0);
        }
      // k0 đang là chỉ số nến trong m_pre: coi như đã chạm lúc nạp lịch sử (phản ứng k0+1 nếu có rơi vào nến nạp lịch sử, không vào lệnh)
      for(int x = 0; x < n; x++)
         if(z[x].s.k0 >= 0)
           {
            z[x].s.k0 = -2;
            z[x].s.fired = 7;
           }
      MqlDateTime d;
      TimeToStruct(iTime(_Symbol, PERIOD_W1, 0), d);
      w1Dow = d.day_of_week;
      PrintFormat("[HTF] nạp lịch sử: M15 %d nến từ %s, H1 %d từ %s, H4 %d từ %s, D1 %d từ %s; xử lý nhanh tới mốc %s: %d / %d / %d / %d; từ mốc tới nến khung vào lệnh đầu tiên (%s) xét như lúc chạy %d nến; nến W1 bắt đầu thứ %d (0 = CN)",
                  T[0].warmGot, TimeToString(T[0].warmFirst), T[1].warmGot, TimeToString(T[1].warmFirst), T[2].warmGot,
                  TimeToString(T[2].warmFirst), T[3].warmGot, TimeToString(T[3].warmFirst), TimeToString(cut), T[0].drained,
                  T[1].drained, T[2].drained, T[3].drained, TimeToString(T0), preGot, w1Dow);
     }

   // Nến khung vào lệnh mở lúc te: nạp mọi nến khung lớn đã đóng tới te (đóng ≤ te), cập nhật hỏng/lật/tuổi, tạo vùng, thay mức ngày/tuần.
   // Gọi sau khi xử lý nến khung vào lệnh vừa đóng (vùng biết lúc te chỉ dùng từ nến mở lúc te). live = false khi nạp lịch sử: lúc đó
   // nến của sàn đã tới giờ bắt đầu đo nên không so "nến đóng mới nhất của sàn" được.
   void              Sync(datetime te, const CSmcBars &E, bool live)
     {
      for(int k = 0; k < HTF_COUNT; k++)
        {
         T[k].nq = 0;
         T[k].fetched = false;
         if(te < T[k].lastOpen + 2 * T[k].P)
            continue;   // chưa thể có nến mới đã đóng
         if(!(bool)SeriesInfoInteger(_Symbol, T[k].tf, SERIES_SYNCHRONIZED))
           {
            late++;
            continue;
           }
         MqlRates r[];
         ArraySetAsSeries(r, false);
         int got = CopyRates(_Symbol, T[k].tf, (datetime)(T[k].lastOpen + 1), (datetime)(te - 1), r);
         if(got < 0)
           {
            late++;   // chưa lấy được: không đổi lastOpen, lần sau lấy lại
            continue;
           }
         T[k].fetched = true;
         for(int x = 0; x < got; x++)
            if(r[x].time > T[k].lastOpen && r[x].time + T[k].P <= te)
               T[k].Queue(r[x]);
        }
      IngestQueued(te, E, false);
      for(int k = 0; k < HTF_COUNT && live; k++)
         if(T[k].fetched && iTime(_Symbol, T[k].tf, 1) > T[k].lastOpen)
            late++;   // sàn đã có nến đóng mới hơn mà chưa nạp
      RollWeek(te, te, E, false);
      Compact();
     }

   // Giờ mở nến khung vào lệnh mới (open = giá mở, Bid tick đầu): vùng chưa chạm, chưa đúng phía mà nến mở đúng phía thì nhận chạm từ nến này
   void              ArmCheck(double open, datetime te)
     {
      for(int k = 0; k < n; k++)
        {
         if(z[k].armedAt != 0 || z[k].s.k0 != -1)
            continue;
         bool ok = z[k].s.dir > 0 ? open > z[k].s.top : open < z[k].s.bottom;
         if(!z[k].armChecked && !ok)
            cUnarmed[z[k].tf][z[k].s.type]++;
         z[k].armChecked = true;
         if(ok)
           {
            z[k].armedAt = te;
            lg[z[k].s.id].armedAt = te;
           }
        }
     }

   // Nến khung vào lệnh i vừa đóng: lần chạm đầu (vùng đã đúng phía) và phản ứng R1–R3 ở k0, k0+1 như SmcZones; không hỏng, không hết
   // tuổi theo nến khung vào lệnh
   void              OnBar(const CSmcBars &E, int i)
     {
      ArrayInitialize(touched, 0);
      ArrayInitialize(react, 0);
      SmcBar b = E.b[i];
      for(int k = 0; k < n; k++)
        {
         int k0 = z[k].s.k0;
         int side = z[k].s.dir > 0 ? ZS_BUY : ZS_SELL;
         if(k0 == -1)
           {
            if(z[k].armedAt == 0 || !ZTouch(z[k].s.dir, z[k].s.top, z[k].s.bottom, b))
               continue;
            if(z[k].known > b.t)
               useEarly++;
            z[k].s.k0 = i;
            z[k].s.m1Touched = true;
            lg[z[k].s.id].touch = b.t;
            cTouch[z[k].tf][z[k].s.type]++;
            touched[z[k].s.type] |= side;
           }
         else
            if(k0 != i - 1)
               continue;
         SmcZone q = z[k].s;
         datetime touch = lg[q.id].touch;
         if((q.fired & (1 << ZR_R1)) == 0 && IsR1(q, b))
           {
            q.fired |= 1 << ZR_R1;
            KeepRep(k, ZR_R1, side, touch);
            react[q.type * 3 + ZR_R1] |= side;
           }
         if((q.fired & (1 << ZR_R2)) == 0 && i >= 1 && IsR2(q, E.b[i - 1], b))
           {
            q.fired |= 1 << ZR_R2;
            KeepRep(k, ZR_R2, side, touch);
            react[q.type * 3 + ZR_R2] |= side;
           }
         if((q.fired & (1 << ZR_R3)) == 0 && IsR3(q, b))
           {
            q.fired |= 1 << ZR_R3;
            KeepRep(k, ZR_R3, side, touch);
            react[q.type * 3 + ZR_R3] |= side;
           }
         if(q.fired != z[k].s.fired && z[k].known > b.t)
            useEarly++;
         z[k].s.fired = q.fired;
        }
     }

   // Nến M1 vừa đóng (R4, khung vào lệnh M5): vùng đã đúng phía được nến M1 chạm lần đầu
   void              OnM1Bar(const SmcBar &m, HtfHit &hits[], int &nHits)
     {
      nHits = 0;
      for(int k = 0; k < n; k++)
        {
         if(z[k].s.m1Touched || z[k].armedAt == 0 || !ZTouch(z[k].s.dir, z[k].s.top, z[k].s.bottom, m))
            continue;
         if(z[k].known > m.t)
            useEarly++;
         z[k].s.m1Touched = true;
         if(nHits >= ArraySize(hits))
            ArrayResize(hits, 2 * nHits + 16);
         hits[nHits].type = z[k].s.type;
         hits[nHits].dir = z[k].s.dir;
         hits[nHits].top = z[k].s.top;
         hits[nHits].bottom = z[k].s.bottom;
         hits[nHits].ref = RefOf(k, m.t);
         nHits++;
        }
     }

   // 25.5: vùng khung vào lệnh q được chạm đầu ở nến mở lúc open (trạng thái khung lớn lúc đó): trùng khi có vùng khung lớn cùng vai, còn
   // sống, loại FVG/OB/SNR/ngày-tuần, giao với q sau khi nới d = 0,3 × ATR M15 của nến M15 đã đóng cuối; lấy vùng khung lớn nhất.
   // MSNR khung lớn chỉ ghi cờ. count = false (nến M1 chạm trước, R4): chỉ gắn nhãn, không đếm, vì nến khung vào lệnh chứa nó đếm lần chạm này.
   virtual void      Tag(SmcZone &q, datetime open, bool count)
     {
      double d = T[0].B.n > 0 ? 0.3 * T[0].B.b[T[0].B.n - 1].atr : 0.0;
      int best = -1;
      bool msnr = false;
      for(int k = 0; k < n; k++)
        {
         if(z[k].s.dir != q.dir || q.bottom > z[k].s.top + d || q.top < z[k].s.bottom - d)
            continue;
         if(z[k].known > open)
           {
            useEarly++;
            continue;
           }
         if(z[k].s.type == HZ_MSNR)
           {
            msnr = true;
            continue;
           }
         if(best < 0 || z[k].tf > z[best].tf)
            best = k;
        }
      ZeroMemory(q.tag);
      q.tag.ovl = best >= 0 ? 1 : 0;
      q.tag.msnr = msnr;
      q.tag.d = d;
      q.tag.at = open;
      q.tag.hId = -1;
      q.tag.hTf = -1;
      q.tag.hType = -1;
      if(best >= 0)
        {
         q.tag.hId = z[best].s.id;
         q.tag.hTf = z[best].tf;
         q.tag.hType = z[best].s.type;
         q.tag.hTop = z[best].s.top;
         q.tag.hBottom = z[best].s.bottom;
        }
      if(!count)
         return;
      cTag++;
      if(best >= 0)
         cTagOvl++;
      if(msnr)
         cTagMsnr++;
     }

   // Cuối lần chạy (nến W1 đã đủ): so mỗi cặp PWH/PWL với nến W1 của sàn cùng nhãn tuần (nhãn = CN trước thứ Hai của tuần đó).
   // w1Alt: trong các tuần khác, số tuần mà nến W1 đó khớp cao/thấp của nến D1 gốc từ T2 tới CN tuần sau (giải thích chỗ khác)
   void              W1Check(void)
     {
      pwChecked = 0;
      pwMismatch = 0;
      w1Alt = 0;
      for(int id = 0; id + 1 < nLog; id++)
        {
         if(lg[id].tf != HF_WEEK || lg[id].dir0 != -1 || lg[id + 1].tf != HF_WEEK)
            continue;
         datetime mon = (datetime)((long)HtfWeekKey(lg[id].origin) * 86400);
         int sh = iBarShift(_Symbol, PERIOD_W1, (datetime)(mon - 86400), true);
         if(sh < 0)
            continue;
         double wh = iHigh(_Symbol, PERIOD_W1, sh), wl = iLow(_Symbol, PERIOD_W1, sh);
         pwChecked++;
         if(MathAbs(wh - lg[id].top) <= _Point / 2.0 && MathAbs(wl - lg[id + 1].bottom) <= _Point / 2.0)
            continue;
         pwMismatch++;
         MqlRates r[];
         int got = CopyRates(_Symbol, PERIOD_D1, mon, (datetime)(mon + 6 * 86400), r);
         double ah = -DBL_MAX, al = DBL_MAX;
         for(int k = 0; k < got; k++)
           {
            ah = MathMax(ah, r[k].high);
            al = MathMin(al, r[k].low);
           }
         if(got > 0 && MathAbs(ah - wh) <= _Point / 2.0 && MathAbs(al - wl) <= _Point / 2.0)
            w1Alt++;
        }
     }

   // Các dòng đầu tong_ket.txt về khung lớn (mỗi dòng bắt đầu "HTF")
   void              HeaderLines(string &out[], int &nl) const
     {
      out[nl++] = StringFormat("HTF nạp lịch sử (yêu cầu M15 1500, H1 1000, H4 700, D1 600 nến): M15 %d nến từ %s, H1 %d từ %s, H4 %d từ %s, D1 %d nến gốc từ %s; mốc %s (00:00 T3–T7 gần nhất ≤ nến khung vào lệnh nạp lịch sử đầu tiên, không nến khung lớn nào vắt qua mốc): nến đóng trước mốc xử lý nhanh M15 %d, H1 %d, H4 %d, D1 %d (đúng phía/chạm theo nến của khung nhỏ nhất đã có lịch sử: M15 từ %s, H1 từ %s, H4 từ %s, trước đó D1; không nhỏ hơn khung của vùng; mức ngày/tuần như D1); từ mốc tới nến khung vào lệnh nạp lịch sử đầu tiên xét như lúc chạy trên %d nến khung vào lệnh; nến D1 CN/T7 gộp vào ngày kế tiếp %d, nến D1 sau gộp %d; nến W1 của sàn bắt đầu thứ %d (0 = Chủ nhật).",
                               T[0].warmGot, TimeToString(T[0].warmFirst), T[1].warmGot, TimeToString(T[1].warmFirst), T[2].warmGot,
                               TimeToString(T[2].warmFirst), T[3].warmGot, TimeToString(T[3].warmFirst), TimeToString(cut), T[0].drained,
                               T[1].drained, T[2].drained, T[3].drained, TimeToString(m_fine[0]), TimeToString(m_fine[1]),
                               TimeToString(m_fine[2]), preGot, T[3].nHeld, T[3].B.n, w1Dow);
      for(int k = 0; k < HTF_COUNT; k++)
        {
         string s = StringFormat("HTF vùng %s (pivot %d/%d; nến đã nạp %d): ", HtfTfName[k], T[k].N, T[k].N, T[k].B.n);
         for(int t = 0; t < HZ_DW; t++)
            s += StringFormat("%s tạo %d, gộp lên khung lớn %d, hỏng %d, hết tuổi %d, chưa đúng phía lúc biết %d, chạm đầu %d (+ %d lúc xử lý nhanh trước mốc)%s; ",
                              HtfTypeName[t], cCreated[k][t], cMerged[k][t], cClose[k][t], cAge[k][t], cUnarmed[k][t], cTouch[k][t],
                              cWarmTouch[k][t], t == HZ_MSNR ? StringFormat(", lật %d", cFlip[k]) : "");
         out[nl++] = s;
        }
      for(int w = 0; w < 2; w++)
        {
         int tf = HF_DAY + w;
         out[nl++] = StringFormat("HTF %s (%s): mức tạo %d, bị thay %d, chưa đúng phía lúc biết %d, chạm đầu %d (+ %d lúc xử lý nhanh trước mốc); cực trị in trong 15 phút sau mở cửa hoặc 30 phút trước giờ nghỉ: %d mức; so cực trị với nến khung vào lệnh: %d kỳ đủ nến, lệch %d mức (phải bằng 0)",
                                  HtfTfName[tf], w == 0 ? "PDH/PDL" : "PWH/PWL", cCreated[tf][HZ_DW], cReplaced[tf], cUnarmed[tf][HZ_DW],
                                  cTouch[tf][HZ_DW], cWarmTouch[tf][HZ_DW], cNearBreak[w], extChecked[w], extMismatch[w]);
        }
      out[nl++] = StringFormat("HTF gắn nhãn trùng (25.5) cho %d lần chạm đầu vùng khung vào lệnh (mỗi lần chạm đầu đếm một lần ở nến khung vào lệnh, kể cả nến nạp lịch sử; R4 gắn nhãn thêm ở nến M1 chạm, không đếm lại): trùng %d; trùng MSNR khung lớn (chỉ ghi) %d.",
                               cTag, cTagOvl, cTagMsnr);
      out[nl++] = StringFormat("HTF tự kiểm tra (phải bằng 0): dùng vùng khung lớn trước lúc biết %d; nạp nến khung lớn trước khi đóng %d; nạp trễ (lỗi lấy nến, hoặc lúc chạy sàn đã có nến đóng mới hơn mà chưa nạp) %d. PWH/PWL so với nến W1 của sàn cùng nhãn tuần (so ở cuối lần chạy): khác %d / %d tuần, trong đó %d tuần nến W1 = cao/thấp của nến D1 gốc từ T2 tới CN tuần sau%s.",
                               useEarly, ingestEarly, late, pwMismatch, pwChecked, w1Alt,
                               pwMismatch == 0 ? "" : " (nến W1 trong đoạn tester tự dựng tính tuần từ T2 00:00 và gồm phiên CN tối tuần sau; nến W1 lịch sử của sàn tính CN–T7 như PWH/PWL; SPEC 25.3 không đọc W1, xem w1_san.csv)");
     }

   // vung_htf.csv: mọi vùng khung lớn đã tạo; d1_gop.csv: nến D1 sau gộp; d1_san.csv: nến D1 gốc của sàn (để đối chiếu PDH/PDL)
   void              WriteFiles(string folder) const
     {
      int h = FileOpen(folder + "vung_htf.csv", FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON, 0, CP_UTF8);
      if(h != INVALID_HANDLE)
        {
         FileWriteString(h, "# vung khung lon SPEC 25; chieu_dau: 1 do, -1 can (MSNR co the lat, xem so_lan_lat); ly_do_het: 0 con song, 1 nen khung dong qua mep xa, 2 het tuoi, 3 gop vao vung khung lon (gop_vao), 4 ngay/tuan moi thay; dung_phia_luc = gio mo nen mo dung phia dau tien, cham_dau_luc = gio mo nen cham dau, ca hai cua vai hien tai (MSNR lat thi xoa, ghi lai theo vai moi); tu_lich_su 1 = tao luc xu ly nhanh truoc moc nap lich su (xem dong HTF nap lich su trong tong_ket.txt)\r\n");
         FileWriteString(h, "ma;khung;loai;chieu_dau;day;dinh;nen_goc;biet_luc;dung_phia_luc;cham_dau_luc;het_luc;ly_do_het;gop_vao;so_lan_lat;gan_gio_nghi;tu_lich_su\r\n");
         for(int k = 0; k < nLog; k++)
            FileWriteString(h, StringFormat("%d;%s;%s;%d;%s;%s;%s;%s;%s;%s;%s;%d;%d;%d;%d;%d\r\n", k, HtfTfName[lg[k].tf], HtfTypeName[lg[k].type],
                                            lg[k].dir0, DoubleToString(lg[k].bottom, _Digits), DoubleToString(lg[k].top, _Digits),
                                            TimeToString(lg[k].origin), TimeToString(lg[k].known), lg[k].armedAt > 0 ? TimeToString(lg[k].armedAt) : "",
                                            lg[k].touch > 0 ? TimeToString(lg[k].touch) : "", lg[k].end > 0 ? TimeToString(lg[k].end) : "",
                                            lg[k].endReason, lg[k].mergedInto, lg[k].flips, lg[k].nearBreak, (int)lg[k].warm));
         FileClose(h);
        }
      h = FileOpen(folder + "d1_gop.csv", FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON, 0, CP_UTF8);
      if(h != INVALID_HANDLE)
        {
         FileWriteString(h, "ngay;bat_dau;mo;cao;thap;dong;dong_luc\r\n");
         for(int k = 0; k < T[HT_D1].B.n; k++)
            FileWriteString(h, StringFormat("%s;%s;%s;%s;%s;%s;%s\r\n", TimeToString(T[HT_D1].B.b[k].t, TIME_DATE), TimeToString(T[HT_D1].start[k]),
                                            DoubleToString(T[HT_D1].B.b[k].o, _Digits), DoubleToString(T[HT_D1].B.b[k].h, _Digits),
                                            DoubleToString(T[HT_D1].B.b[k].l, _Digits), DoubleToString(T[HT_D1].B.b[k].c, _Digits),
                                            TimeToString(T[HT_D1].B.b[k].t + 86400)));
         FileClose(h);
        }
      MqlRates r[];
      ArraySetAsSeries(r, false);
      int got = CopyRates(_Symbol, PERIOD_D1, T[HT_D1].warmFirst, TimeCurrent(), r);
      h = FileOpen(folder + "d1_san.csv", FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON, 0, CP_UTF8);
      if(h != INVALID_HANDLE)
        {
         FileWriteString(h, "ngay;thu;mo;cao;thap;dong\r\n");
         for(int k = 0; k < got; k++)
           {
            MqlDateTime d;
            TimeToStruct(r[k].time, d);
            FileWriteString(h, StringFormat("%s;%d;%s;%s;%s;%s\r\n", TimeToString(r[k].time, TIME_DATE), d.day_of_week, DoubleToString(r[k].open, _Digits),
                                            DoubleToString(r[k].high, _Digits), DoubleToString(r[k].low, _Digits), DoubleToString(r[k].close, _Digits)));
           }
         FileClose(h);
        }
      got = CopyRates(_Symbol, PERIOD_W1, T[HT_D1].warmFirst, TimeCurrent(), r);
      h = FileOpen(folder + "w1_san.csv", FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON, 0, CP_UTF8);
      if(h != INVALID_HANDLE)
        {
         FileWriteString(h, "tuan;mo;cao;thap;dong\r\n");
         for(int k = 0; k < got; k++)
            FileWriteString(h, StringFormat("%s;%s;%s;%s;%s\r\n", TimeToString(r[k].time, TIME_DATE), DoubleToString(r[k].open, _Digits),
                                            DoubleToString(r[k].high, _Digits), DoubleToString(r[k].low, _Digits), DoubleToString(r[k].close, _Digits)));
         FileClose(h);
        }
     }
  };

#endif
