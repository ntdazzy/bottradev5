// Sổ lệnh của BotFvgNhanChim (SPEC §23.2): các lệnh đang mở của bot (đúng Magic + Symbol). Thông tin lúc vào lệnh (nến tín hiệu,
// vùng, giá gửi, dừng lỗ, chốt lời, lý do bot đang đóng) lưu trong State, mỗi lệnh một chỗ, nên khởi động lại không mất.
// Đối chiếu với sàn: nhận lại lệnh đang mở, gắn thông tin tín hiệu cho lệnh vừa gửi, đọc kết quả lệnh đã đóng từ lịch sử deal
// (kể cả lệnh đóng lúc bot không chạy).
#ifndef BOTVANG_FVGNCBOOK_MQH
#define BOTVANG_FVGNCBOOK_MQH

#include "State.mqh"

#define FB_SLOTS  32   // số chỗ lưu (bot mở tối đa 20 lệnh)

// Lý do đóng lệnh; 1–4 cùng mã với cột ly_do của PhanUngLab
#define FX_TP     1
#define FX_SL     2
#define FX_TIME   3    // giữ đủ 500 nến
#define FX_END    4    // còn mở lúc hết dữ liệu (Strategy Tester)
#define FX_LIMIT  5    // bot đóng vì giới hạn lỗ
#define FX_OTHER  6    // đóng tay hoặc lý do khác
#define FX_SO     7    // sàn cắt lệnh vì thiếu ký quỹ (stop out)

struct FvgTrade
  {
   long              id;          // POSITION_IDENTIFIER
   ulong             ticket;      // 0: chưa thấy trên sàn trong lần chạy này
   int               slot;        // chỗ lưu trong State; −1: hết chỗ
   datetime          sig;         // giờ mở nến tín hiệu (0: không rõ)
   int               dir;
   double            zTop, zBot;  // vùng FVG có phản ứng (0: không rõ)
   int               zones;       // số vùng FVG cùng phản ứng ở nến tín hiệu
   double            want;        // giá lúc gửi lệnh (mua Ask, bán Bid); 0: lệnh nhận lại, không rõ
   double            sl, tp;      // dừng lỗ / chốt lời lúc vào lệnh
   double            fill;        // giá khớp
   datetime          fillTime;
   double            vol;
   int               closeWhy;    // bot đang đóng lệnh này (FX_TIME, FX_LIMIT); 0: không
   datetime          closeSent;   // lúc gửi đóng gần nhất
   int               miss;        // số lần chưa đọc được deal đóng sau khi lệnh biến mất
  };

// Kết quả một lệnh đã đóng
struct FvgExit
  {
   bool              known;       // đọc được deal đóng
   datetime          time;
   double            price;       // giá đóng (nhiều deal đóng: bình quân theo khối lượng)
   int               reason;      // FX_*
   double            money;       // lời/lỗ + phí qua đêm + hoa hồng + phí, theo tiền tài khoản
  };

class CFvgBook
  {
private:
   CState           *m_st;
   string            m_sym;
   long              m_magic;
   string            m_tag;
   bool              m_hasWant;   // lệnh vừa gửi, chờ thấy trên sàn để gắn thông tin tín hiệu
   FvgTrade          m_want;
   string            m_wantTag;
   datetime          m_wantAt;

   static string     K(int s, const string f) { return "s" + (string)s + f; }

   void              Save(const FvgTrade &x)
     {
      if(x.slot < 0)
         return;
      m_st.Set(K(x.slot, "i"), (double)x.id);
      m_st.Set(K(x.slot, "g"), (double)x.sig);
      m_st.Set(K(x.slot, "d"), x.dir);
      m_st.Set(K(x.slot, "t"), x.zTop);
      m_st.Set(K(x.slot, "b"), x.zBot);
      m_st.Set(K(x.slot, "n"), x.zones);
      m_st.Set(K(x.slot, "w"), x.want);
      m_st.Set(K(x.slot, "l"), x.sl);
      m_st.Set(K(x.slot, "p"), x.tp);
      m_st.Set(K(x.slot, "c"), x.closeWhy);
     }

   void              Unsave(int slot)
     {
      if(slot < 0)
         return;
      string f[] = {"i", "g", "d", "t", "b", "n", "w", "l", "p", "c"};
      for(int k = 0; k < ArraySize(f); k++)
         m_st.Del(K(slot, f[k]));
     }

   int               FreeSlot(void) const
     {
      for(int s = 0; s < FB_SLOTS; s++)
        {
         bool used = m_st.Has(K(s, "i"));
         for(int k = 0; k < n && !used; k++)
            used = t[k].slot == s;
         if(!used)
            return s;
        }
      return -1;
     }

   int               Find(long id) const
     {
      for(int k = 0; k < n; k++)
         if(t[k].id == id)
            return k;
      return -1;
     }

   void              Remove(int k)
     {
      Unsave(t[k].slot);
      for(int j = k; j < n - 1; j++)
         t[j] = t[j + 1];
      n--;
      ArrayResize(t, n, 32);
     }

   // Lệnh (đã chọn bằng PositionGetTicket) chưa có trong sổ: gắn thông tin lệnh vừa gửi nếu cùng ghi chú hoặc mở sau lúc gửi;
   // không thì nhận lại, nến tín hiệu đọc từ ghi chú "<tag> yyyy.mm.dd hh:mi" nếu được
   void              Adopt(ulong ticket, FvgTrade &x)
     {
      string comment = PositionGetString(POSITION_COMMENT);
      datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(m_hasWant && (comment == m_wantTag || opened >= m_wantAt))
        {
         x = m_want;
         m_hasWant = false;
        }
      else
        {
         ZeroMemory(x);
         if(StringFind(comment, m_tag + " ") == 0)
            x.sig = StringToTime(StringSubstr(comment, StringLen(m_tag) + 1));
        }
      x.id = PositionGetInteger(POSITION_IDENTIFIER);
      x.ticket = ticket;
      x.dir = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 1 : -1;
      x.sl = PositionGetDouble(POSITION_SL);
      x.tp = PositionGetDouble(POSITION_TP);
      x.fill = PositionGetDouble(POSITION_PRICE_OPEN);
      x.fillTime = opened;
      x.vol = PositionGetDouble(POSITION_VOLUME);
      x.closeWhy = 0;
      x.closeSent = 0;
      x.miss = 0;
      x.slot = FreeSlot();
     }

   // Kết quả của lệnh đã đóng từ lịch sử deal; false nếu chưa có deal đóng (lịch sử chưa về)
   bool              ReadExit(FvgTrade &x, FvgExit &e)
     {
      ZeroMemory(e);
      if(!HistorySelectByPosition(x.id))
         return false;
      double vol = 0.0, sum = 0.0;
      long reason = -1;
      string comment = "";
      for(int i = 0; i < HistoryDealsTotal(); i++)
        {
         ulong d = HistoryDealGetTicket(i);
         if(d == 0)
            continue;
         e.money += HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_SWAP) + HistoryDealGetDouble(d, DEAL_COMMISSION)
                    + HistoryDealGetDouble(d, DEAL_FEE);
         long entry = HistoryDealGetInteger(d, DEAL_ENTRY);
         if(entry == DEAL_ENTRY_IN)
           {
            if(x.fillTime == 0)   // lệnh đóng lúc bot không chạy, chưa từng thấy trên sàn
              {
               x.fill = HistoryDealGetDouble(d, DEAL_PRICE);
               x.fillTime = (datetime)HistoryDealGetInteger(d, DEAL_TIME);
              }
            continue;
           }
         if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY)
            continue;
         double v = HistoryDealGetDouble(d, DEAL_VOLUME);
         vol += v;
         sum += v * HistoryDealGetDouble(d, DEAL_PRICE);
         e.time = (datetime)HistoryDealGetInteger(d, DEAL_TIME);
         reason = HistoryDealGetInteger(d, DEAL_REASON);
         comment = HistoryDealGetString(d, DEAL_COMMENT);
        }
      if(vol <= 0.0)
         return false;
      e.known = true;
      e.price = sum / vol;
      if(reason == DEAL_REASON_SL)
         e.reason = FX_SL;
      else
         if(reason == DEAL_REASON_TP)
            e.reason = FX_TP;
         else
            if(reason == DEAL_REASON_SO)
               e.reason = FX_SO;
            else
               if(reason == DEAL_REASON_EXPERT && x.closeWhy != 0)
                  e.reason = x.closeWhy;
               else
                  e.reason = StringFind(comment, "end of test") >= 0 ? FX_END : FX_OTHER;
      return true;
     }

public:
   FvgTrade          t[];
   int               n;

   void              Init(CState *st, const string sym, long magic, const string tag)
     {
      m_st = st;
      m_sym = sym;
      m_magic = magic;
      m_tag = tag;
      m_hasWant = false;
      n = 0;
      ArrayResize(t, 0, 32);
     }

   // Nạp các lệnh đã lưu ở lần chạy trước (gọi một lần khi khởi động, trước Sync)
   void              Load(void)
     {
      for(int s = 0; s < FB_SLOTS; s++)
        {
         if(!m_st.Has(K(s, "i")))
            continue;
         FvgTrade x;
         ZeroMemory(x);
         x.slot = s;
         x.id = (long)m_st.Get(K(s, "i"));
         x.sig = (datetime)m_st.Get(K(s, "g"));
         x.dir = (int)m_st.Get(K(s, "d"));
         x.zTop = m_st.Get(K(s, "t"));
         x.zBot = m_st.Get(K(s, "b"));
         x.zones = (int)m_st.Get(K(s, "n"));
         x.want = m_st.Get(K(s, "w"));
         x.sl = m_st.Get(K(s, "l"));
         x.tp = m_st.Get(K(s, "p"));
         x.closeWhy = (int)m_st.Get(K(s, "c"));
         ArrayResize(t, n + 1, 32);
         t[n++] = x;
        }
     }

   // Trước khi gửi lệnh mở: thông tin tín hiệu để gắn vào lệnh khi thấy trên sàn
   void              Expect(const FvgTrade &x, const string tag)
     {
      m_want = x;
      m_wantTag = tag;
      m_wantAt = TimeCurrent();
      m_hasWant = true;
     }
   void              CancelWant(void) { m_hasWant = false; }
   bool              HasWant(void) const { return m_hasWant; }
   datetime          WantAt(void) const { return m_wantAt; }

   // Bot bắt đầu đóng lệnh k vì why (FX_TIME, FX_LIMIT); lưu lại để sau khởi động lại vẫn biết lý do
   void              RequestClose(int k, int why)
     {
      t[k].closeWhy = why;
      t[k].closeSent = 0;
      Save(t[k]);
     }

   // Đối chiếu với sàn. Lệnh mới thấy → opened[]; lệnh đã biến mất và đọc được deal đóng → closed[] + exits[] rồi bỏ khỏi sổ
   // (sau 60 lần không đọc được lịch sử thì cũng bỏ, exits[].known = false). Trả về số lệnh đã đóng.
   int               Sync(FvgTrade &opened[], FvgTrade &closed[], FvgExit &exits[])
     {
      ArrayResize(opened, 0);
      ArrayResize(closed, 0);
      ArrayResize(exits, 0);
      bool seen[];
      ArrayResize(seen, n);
      ArrayInitialize(seen, false);
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong tk = PositionGetTicket(i);
         if(tk == 0 || PositionGetInteger(POSITION_MAGIC) != m_magic || PositionGetString(POSITION_SYMBOL) != m_sym)
            continue;
         int k = Find(PositionGetInteger(POSITION_IDENTIFIER));
         if(k >= 0)
           {
            seen[k] = true;
            if(t[k].ticket == 0)   // lệnh đã lưu từ lần chạy trước: đọc giá khớp từ sàn
              {
               t[k].ticket = tk;
               t[k].fill = PositionGetDouble(POSITION_PRICE_OPEN);
               t[k].fillTime = (datetime)PositionGetInteger(POSITION_TIME);
               t[k].vol = PositionGetDouble(POSITION_VOLUME);
              }
            continue;
           }
         FvgTrade x;
         Adopt(tk, x);
         ArrayResize(t, n + 1, 32);
         t[n++] = x;
         ArrayResize(seen, n);
         seen[n - 1] = true;
         Save(x);
         int m = ArraySize(opened);
         ArrayResize(opened, m + 1);
         opened[m] = x;
        }
      for(int k = n - 1; k >= 0; k--)
        {
         if(seen[k])
            continue;
         FvgExit e;
         if(!ReadExit(t[k], e) && ++t[k].miss < 60)
            continue;
         int m = ArraySize(closed);
         ArrayResize(closed, m + 1);
         ArrayResize(exits, m + 1);
         closed[m] = t[k];
         exits[m] = e;
         Remove(k);
        }
      return ArraySize(closed);
     }
  };

#endif
