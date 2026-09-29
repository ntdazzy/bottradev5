// Vùng giá của PhanUngLab (SPEC §22.1) trên nến đã đóng của khung vào lệnh: FVG, OB (cả 2 lớp cấu trúc), SNR (đỉnh/đáy pivot 5/5),
// MSNR (mức A/V, đóng qua thì lật vai trò), EMA 20/50/200 (lần chạm sau 5 nến nằm hẳn một phía). Ghi lần chạm đầu (nến k0), xét nến
// phản ứng R1–R3 (SPEC §22.2) ở k0 và k0+1, và hình dạng mẫu nến không cần vùng cho nhóm X1 (SPEC §22.4). Chỉ tìm và ghi sổ,
// không vào lệnh. Mỗi vùng dùng được từ nến sau lúc xuất hiện thật (không nhìn trước).
// Có tagger (PhanUngLab khi bật cản khung lớn, SPEC §25.5) thì lần chạm đầu được gắn nhãn trùng và giữ vùng đại diện của mỗi ô đã phản ứng;
// không có tagger (mặc định, BotFvgNhanChim) thì hành vi như cũ.
#ifndef BOTVANG_SMCZONES_MQH
#define BOTVANG_SMCZONES_MQH

#include "SmcDetect.mqh"

#define ZT_FVG     0
#define ZT_OB      1
#define ZT_SNR     2
#define ZT_MSNR    3
#define ZT_EMA     4
#define ZT_COUNT   5

#define ZR_R1      0   // nến rút râu
#define ZR_R2      1   // nến nhấn chìm
#define ZR_R3      2   // đóng quay ra khỏi vùng

#define ZS_BUY     1   // bit chiều trong mặt nạ: vùng đỡ → mua
#define ZS_SELL    2   // vùng cản → bán

#define ZEMA_COUNT 3
#define ZEMA_FRESH 5   // số nến trước phải nằm hẳn một phía EMA

// Nhãn "trùng vùng khung lớn" (SPEC §25.5) gắn lúc chạm đầu; chỉ PhanUngLab bật (qua tagger), bot khác để nguyên −1
struct SmcTag
  {
   int               ovl;         // 1 trùng vùng khung lớn H, 0 không, −1 chưa xét
   int               hId, hTf, hType;   // vùng H (khi ovl = 1)
   double            hTop, hBottom;
   double            d;           // độ nới 0,3 × ATR M15 lúc xét
   bool              msnr;        // trùng MSNR khung lớn (chỉ ghi, không tính là trùng)
   datetime          at;          // giờ mở nến chạm lúc xét
  };

struct SmcZone
  {
   int               type;
   int               dir;         // +1 vùng đỡ (chỉ mua), −1 vùng cản (chỉ bán)
   double            top, bottom;
   int               born;        // nến xuất hiện; dùng được từ nến born+1
   int               k0;          // nến chạm đầu; −1: chưa chạm
   int               fired;       // bit ZR_*: kiểu phản ứng đã báo ở vùng này (mỗi kiểu một lần)
   bool              m1Touched;   // đã có nến M1 chạm lần đầu (R4)
   int               id;          // mã vùng theo thứ tự tạo
   SmcTag            tag;
  };

// Vùng vừa được một nến M1 chạm lần đầu (bản sao để theo dõi R4)
struct SmcZoneHit
  {
   int               type;
   int               dir;
   double            top, bottom;
   int               id;          // −1: mức EMA
   int               born;
   SmcTag            tag;
  };

// Người gắn nhãn trùng (PhanUngLab: vùng khung lớn); gọi lúc vùng được chạm đầu với giờ mở nến chạm. count = true ở nến khung vào lệnh
// (mỗi lần chạm đầu một lần); false ở nến M1 chạm trước trong nến khung vào lệnh đang chạy (R4), lần chạm đó được đếm ở nến khung vào lệnh
class ISmcTagger
  {
public:
   virtual void      Tag(SmcZone &q, datetime open, bool count) = 0;
  };

double ZBody(const SmcBar &b) { return MathAbs(b.c - b.o); }
// Râu phía phản ứng: mua (vùng đỡ) → râu dưới; bán → râu trên
double ZWick(int dir, const SmcBar &b) { return dir > 0 ? MathMin(b.o, b.c) - b.l : b.h - MathMax(b.o, b.c); }
// Chạm vùng: vùng đỡ khi low ≤ đỉnh vùng; vùng cản khi high ≥ đáy vùng
bool ZTouch(int dir, double top, double bottom, const SmcBar &b) { return dir > 0 ? b.l <= top : b.h >= bottom; }
bool ZTouch(const SmcZone &z, const SmcBar &b) { return ZTouch(z.dir, z.top, z.bottom, b); }
// Đóng quay ra khỏi vùng: vùng đỡ đóng > đỉnh; vùng cản đóng < đáy
bool ZCloseOut(const SmcZone &z, const SmcBar &b) { return z.dir > 0 ? b.c > z.top : b.c < z.bottom; }

// R1 nến rút râu: nến k chạm vùng, râu ≥ 2 × thân, đóng quay ra khỏi vùng
bool IsR1(const SmcZone &z, const SmcBar &k) { return ZTouch(z, k) && ZWick(z.dir, k) >= 2.0 * ZBody(k) && ZCloseOut(z, k); }
// R3 đóng quay ra khỏi vùng: nến k chạm vùng và đóng quay ra
bool IsR3(const SmcZone &z, const SmcBar &k) { return ZTouch(z, k) && ZCloseOut(z, k); }

// Hình dạng nhấn chìm chiều dir (chỉ xét thân): mua = nến trước đỏ, nến k xanh, đóng k ≥ mở trước, mở k ≤ đóng trước (ít nhất
// một dấu chặt), thân k > thân trước. Bán ngược lại.
bool EngulfShape(int dir, const SmcBar &p, const SmcBar &k)
  {
   bool ok = dir > 0 ? p.c < p.o && k.c > k.o && k.c >= p.o && k.o <= p.c && (k.c > p.o || k.o < p.c)
                     : p.c > p.o && k.c < k.o && k.c <= p.o && k.o >= p.c && (k.c < p.o || k.o > p.c);
   return ok && ZBody(k) > ZBody(p);
  }
// R2 nến nhấn chìm ở vùng: hình dạng nhấn chìm và đóng k không qua mép xa (vùng đỡ: đóng ≥ đáy vùng). Điều kiện "một trong hai
// nến chạm vùng" luôn đúng trong cửa sổ k0..k0+1 (nến k0 chạm) nên không xét lại.
bool IsR2(const SmcZone &z, const SmcBar &p, const SmcBar &k) { return EngulfShape(z.dir, p, k) && (z.dir > 0 ? k.c >= z.bottom : k.c <= z.top); }
// Hình dạng rút râu không cần vùng (X1): râu ≥ 2 × thân; mua: đóng ≥ mở, bán: đóng ≤ mở
bool PinShape(int dir, const SmcBar &k) { return ZWick(dir, k) >= 2.0 * ZBody(k) && (dir > 0 ? k.c >= k.o : k.c <= k.o); }

class CSmcZones
  {
private:
   int               m_emaN[ZEMA_COUNT];
   double            m_ema[ZEMA_COUNT];      // EMA giá đóng tới nến đã đóng cuối (hạt giống = trung bình N giá đóng đầu)
   int               m_emaCnt;
   int               m_above[ZEMA_COUNT];    // số nến liền nhau có low > EMA (EMA tới nến trước nó)
   int               m_below[ZEMA_COUNT];    // số nến liền nhau có high < EMA
   bool              m_emaM1[ZEMA_COUNT * 2];   // mức EMA đang là vùng đã có nến M1 chạm trong nến đang chạy
   int               m_nextId;

   void              Push(int type, int dir, double top, double bottom, int born)
     {
      if(n >= ArraySize(z))
         ArrayResize(z, 2 * n + 256);
      z[n].type = type;
      z[n].dir = dir;
      z[n].top = top;
      z[n].bottom = bottom;
      z[n].born = born;
      z[n].k0 = -1;
      z[n].fired = 0;
      z[n].m1Touched = false;
      z[n].id = m_nextId++;
      ZeroMemory(z[n].tag);
      z[n].tag.ovl = -1;
      n++;
     }

   // Vùng q vừa phản ứng kiểu r ở nến này: giữ một bản làm đại diện cho ô và chiều (ưu tiên vùng trùng khung lớn); chỉ khi có tagger
   void              KeepRep(const SmcZone &q, int r, int side)
     {
      if(tagger == NULL)
         return;
      int k = (q.type * 3 + r) * 2 + (side == ZS_BUY ? 0 : 1);
      if((react[q.type * 3 + r] & side) == 0 || (q.tag.ovl == 1 && rep[k].tag.ovl != 1))
         rep[k] = q;
     }

   // EMA e đang là vùng phía dir cho nến đang chạy: 5 nến trước nằm hẳn một phía; giá vùng = m_ema[e]
   bool              EmaZone(int e, int dir) const
     {
      return m_emaCnt >= m_emaN[e] && (dir > 0 ? m_above[e] : m_below[e]) >= ZEMA_FRESH;
     }

   static bool       PivotHigh(const CSmcBars &B, int p)
     {
      for(int k = 1; k <= 5; k++)
         if(B.b[p].h < B.b[p - k].h || B.b[p].h <= B.b[p + k].h)
            return false;
      return true;
     }
   static bool       PivotLow(const CSmcBars &B, int p)
     {
      for(int k = 1; k <= 5; k++)
         if(B.b[p].l > B.b[p - k].l || B.b[p].l >= B.b[p + k].l)
            return false;
      return true;
     }

   // Hết hạn ở nến i: FVG, SNR 500 nến; OB 300; MSNR 100 (hết trước khi xét chạm, như chỉ báo)
   static bool       Expired(const SmcZone &q, int i)
     {
      int age = i - q.born;
      return (q.type == ZT_MSNR && age >= 100) || (q.type == ZT_OB && age > 300) || ((q.type == ZT_FVG || q.type == ZT_SNR) && age > 500);
     }

   void              AddOb(const SmcBreak &ev, int i)
     {
      if(ev.valid && !ev.initial && ev.ob)
         Push(ZT_OB, ev.dir, ev.obHi, ev.obLo, i);
     }

   static void       AddHit(SmcZoneHit &hits[], int &nHits, const SmcZone &q)
     {
      if(nHits >= ArraySize(hits))
         ArrayResize(hits, 2 * nHits + 16);
      hits[nHits].type = q.type;
      hits[nHits].dir = q.dir;
      hits[nHits].top = q.top;
      hits[nHits].bottom = q.bottom;
      hits[nHits].id = q.id;
      hits[nHits].born = q.born;
      hits[nHits].tag = q.tag;
      nHits++;
     }

public:
   SmcZone           z[];
   int               n;
   // kết quả của nến vừa xét trong OnBar; mặt nạ ZS_* theo loại vùng
   int               touched[ZT_COUNT];         // có vùng loại này được chạm lần đầu
   int               react[ZT_COUNT * 3];       // [loại * 3 + ZR_*]: có vùng loại này phản ứng
   bool              anyTouch;                  // nến chạm ít nhất một vùng còn sống (kể cả vùng đã dùng)
   ISmcTagger       *tagger;                    // NULL: không gắn nhãn trùng (mặc định)
   SmcZone           rep[ZT_COUNT * 3 * 2];     // [(loại * 3 + ZR_*) * 2 + (mua 0 / bán 1)]: vùng đại diện đã phản ứng (chỉ khi có tagger)

   void              Init(void)
     {
      n = 0;
      m_nextId = 0;
      tagger = NULL;
      ArrayResize(z, 0);
      m_emaN[0] = 20;
      m_emaN[1] = 50;
      m_emaN[2] = 200;
      m_emaCnt = 0;
      ArrayInitialize(m_ema, 0.0);
      ArrayInitialize(m_above, 0);
      ArrayInitialize(m_below, 0);
      ArrayInitialize(m_emaM1, false);
     }

   // Gọi sau khi thêm nến i vào B, sau fvg.OnBar và cấu trúc 2 lớp (ev0: nội bộ, ev1: lớp lớn) của nến i
   void              OnBar(const CSmcBars &B, int i, const SmcBreak &ev0, const SmcBreak &ev1, const CSmcFvgs &fvg)
     {
      ArrayInitialize(touched, 0);
      ArrayInitialize(react, 0);
      anyTouch = false;
      SmcBar b = B.b[i];
      // mức EMA đang là vùng mà nến này chạm: thành vùng EMA (giá cố định lúc chạm), xét như các vùng khác ở nến này và nến sau
      for(int e = 0; e < ZEMA_COUNT; e++)
         for(int s = 1; s >= -1; s -= 2)
            if(EmaZone(e, s) && ZTouch(s, m_ema[e], m_ema[e], b))
               Push(ZT_EMA, s, m_ema[e], m_ema[e], i - 1);
      int keep = 0;
      for(int k = 0; k < n; k++)
        {
         SmcZone q = z[k];
         if(Expired(q, i))
            continue;
         int side = q.dir > 0 ? ZS_BUY : ZS_SELL;
         if(ZTouch(q, b))
           {
            anyTouch = true;
            if(q.k0 < 0)
              {
               q.k0 = i;
               q.m1Touched = true;
               touched[q.type] |= side;
               if(tagger != NULL)
                  tagger.Tag(q, b.t, true);
              }
           }
         // phản ứng ở nến k0 hoặc k0+1, mỗi kiểu một lần mỗi vùng
         if(q.k0 == i || q.k0 == i - 1)
           {
            if((q.fired & (1 << ZR_R1)) == 0 && IsR1(q, b))
              {
               q.fired |= 1 << ZR_R1;
               KeepRep(q, ZR_R1, side);
               react[q.type * 3 + ZR_R1] |= side;
              }
            if((q.fired & (1 << ZR_R2)) == 0 && i >= 1 && IsR2(q, B.b[i - 1], b))
              {
               q.fired |= 1 << ZR_R2;
               KeepRep(q, ZR_R2, side);
               react[q.type * 3 + ZR_R2] |= side;
              }
            if((q.fired & (1 << ZR_R3)) == 0 && IsR3(q, b))
              {
               q.fired |= 1 << ZR_R3;
               KeepRep(q, ZR_R3, side);
               react[q.type * 3 + ZR_R3] |= side;
              }
           }
         // EMA: chạm là dùng, bỏ sau nến k0+1
         if(q.type == ZT_EMA)
           {
            if(i > q.k0)
               continue;
           }
         else
            if(q.dir > 0 ? b.c < q.bottom : b.c > q.top)
              {
               if(q.type != ZT_MSNR)
                  continue;   // hỏng / giá đóng qua mức: hết vùng
               // MSNR đóng qua mức: lật vai trò (cản ↔ đỡ), coi như mức mới (chưa chạm), vẫn tính 100 nến từ lúc xuất hiện
               q.dir = -q.dir;
               q.k0 = -1;
               q.fired = 0;
               q.m1Touched = false;
               q.tag.ovl = -1;
              }
         z[keep++] = q;
        }
      n = keep;
      // EMA và số nến nằm hẳn một phía (so với EMA tới nến trước), rồi cập nhật EMA bằng giá đóng nến i
      for(int e = 0; e < ZEMA_COUNT; e++)
        {
         bool ok = m_emaCnt >= m_emaN[e];
         m_above[e] = ok && b.l > m_ema[e] ? m_above[e] + 1 : 0;
         m_below[e] = ok && b.h < m_ema[e] ? m_below[e] + 1 : 0;
         if(m_emaCnt < m_emaN[e])
            m_ema[e] = (m_ema[e] * m_emaCnt + b.c) / (m_emaCnt + 1);
         else
            m_ema[e] += 2.0 / (m_emaN[e] + 1) * (b.c - m_ema[e]);
        }
      m_emaCnt++;
      ArrayInitialize(m_emaM1, false);
      // vùng mới xuất hiện lúc đóng nến i (dùng được từ nến i+1)
      for(int k = fvg.n - 1; k >= 0 && fvg.f[k].i == i; k--)
         Push(ZT_FVG, fvg.f[k].dir, fvg.f[k].top, fvg.f[k].bottom, i);
      AddOb(ev0, i);
      AddOb(ev1, i);
      int p = i - 5;
      if(p - 5 >= 0)
        {
         if(PivotHigh(B, p))
            Push(ZT_SNR, -1, B.b[p].h, B.b[p].h, i);
         if(PivotLow(B, p))
            Push(ZT_SNR, 1, B.b[p].l, B.b[p].l, i);
        }
      // MSNR: cặp (xanh, đỏ) → mức A (cản); (đỏ, xanh) → mức V (đỡ); giá = giá đóng nến đầu
      if(i >= 1)
        {
         SmcBar a = B.b[i - 1];
         if(a.c > a.o && b.c < b.o)
            Push(ZT_MSNR, -1, a.c, a.c, i);
         else
            if(a.c < a.o && b.c > b.o)
               Push(ZT_MSNR, 1, a.c, a.c, i);
        }
     }

   // Nến M1 vừa đóng trong nến khung vào lệnh đang chạy (chỉ số bar; R4, khung vào lệnh M5): ghi vào hits các vùng được nến M1 chạm
   // lần đầu; trả về true nếu nến M1 chạm ít nhất một vùng còn sống (cho X1). Vùng đã hết hạn ở nến bar thì bỏ, như OnBar.
   bool              OnM1Bar(const SmcBar &m, int bar, SmcZoneHit &hits[], int &nHits)
     {
      nHits = 0;
      bool any = false;
      for(int k = 0; k < n; k++)
        {
         if(Expired(z[k], bar) || !ZTouch(z[k], m))
            continue;
         any = true;
         if(z[k].m1Touched)
            continue;
         z[k].m1Touched = true;
         if(tagger != NULL)
            tagger.Tag(z[k], m.t, false);
         AddHit(hits, nHits, z[k]);
        }
      for(int e = 0; e < ZEMA_COUNT; e++)
         for(int s = 1; s >= -1; s -= 2)
           {
            if(!EmaZone(e, s) || !ZTouch(s, m_ema[e], m_ema[e], m))
               continue;
            any = true;
            int f = e * 2 + (s > 0 ? 0 : 1);
            if(m_emaM1[f])
               continue;
            m_emaM1[f] = true;
            SmcZone q;   // mức EMA chưa thành vùng trong danh sách: bản tạm để ghi và gắn nhãn
            ZeroMemory(q);
            q.type = ZT_EMA;
            q.dir = s;
            q.top = m_ema[e];
            q.bottom = m_ema[e];
            q.born = bar - 1;
            q.id = -1;
            q.tag.ovl = -1;
            if(tagger != NULL)
               tagger.Tag(q, m.t, false);
            AddHit(hits, nHits, q);
           }
      return any;
     }
  };

#endif
