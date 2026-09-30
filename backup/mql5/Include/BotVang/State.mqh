// Trạng thái cần nhớ qua các lần khởi động lại, lưu bằng Global Variables của terminal.
// Tên khóa: BV_<Login>_<Server>_<Symbol>_<Magic>_v2_<khóa>. Chỉ ghi khi giá trị đổi, flush một lần mỗi lượt.
#ifndef BOTVANG_STATE_MQH
#define BOTVANG_STATE_MQH

// Khóa lưu (ngắn để tên không vượt 63 ký tự)
#define SK_POS        "pos"       // mã định danh lệnh đang quản lý (POSITION_IDENTIFIER)
#define SK_POS_B      "posB"      // bước B của lệnh
#define SK_POS_DIR    "posDir"
#define SK_POS_ZONE   "posZone"   // id vùng tạo lệnh
#define SK_WANT_OPEN  "wOpen"     // giá mong muốn lúc vào
#define SK_WANT_SL    "wSl"       // giá dừng lỗ bot đã đặt (để đo trượt khi dính dừng lỗ)
#define SK_FLIP       "flip"      // mã lệnh chờ đảo
#define SK_FLIP_B     "flipB"
#define SK_CONS       "cons"      // số lần dừng lỗ lỗ tiền liên tiếp
#define SK_PAUSE      "pauseTo"   // nghỉ tới lúc nào
#define SK_PAUSE_WHY  "pauseWhy"  // mã lý do nghỉ
#define SK_HARD       "hard"      // dừng hẳn
#define SK_CAPITAL    "cap"       // vốn gốc
#define SK_CAP_TIME   "capT"
#define SK_DAY_EQ     "dayEq"     // Equity lúc bắt đầu ngày VN
#define SK_DAY_KEY    "dayKey"    // ngày VN yyyymmdd của mốc đó
#define SK_WEEK_EQ    "wkEq"
#define SK_WEEK_KEY   "wkKey"
#define SK_BOT_ON     "on"
#define SK_BUY_ON     "buy"
#define SK_SELL_ON    "sell"
#define SK_TIME_ON    "timeOn"
#define SK_FLIP_MODE  "flipMode"
#define SK_LOT        "lot"
#define SK_REQ_KIND   "reqKind"   // yêu cầu mở/đảo đang chờ xác minh
#define SK_REQ_TIME   "reqTime"
#define SK_REQ_TAG    "reqTag"
#define SK_WANT_SL_ID "wSlId"     // mã lệnh (POSITION_IDENTIFIER) mà SK_WANT_SL thuộc về
#define SK_IS_FLIP    "isFlip"    // lệnh đang quản lý là lệnh đảo (không đảo tiếp, như Lab đo)
#define SK_CLOSING    "closing"   // đang ĐÓNG (tiếp tục đóng sau khởi động lại)

class CState
  {
private:
   string            m_prefix;
   bool              m_dirty;

   string            Key(const string k) const { return m_prefix + k; }

public:
   bool              Init(const string sym, long magic)
     {
      string server = AccountInfoString(ACCOUNT_SERVER);
      m_prefix = "BV_" + (string)AccountInfoInteger(ACCOUNT_LOGIN) + "_" + server + "_" + sym + "_" + (string)magic + "_v2_";
      // Tên Global Variable tối đa 63 ký tự: rút gọn tên server nếu cần
      int over = StringLen(m_prefix) + 8 - 63;
      if(over > 0)
         m_prefix = "BV_" + (string)AccountInfoInteger(ACCOUNT_LOGIN) + "_" + StringSubstr(server, 0, MathMax(1, StringLen(server) - over))
                    + "_" + sym + "_" + (string)magic + "_v2_";
      m_dirty = false;
      return StringLen(m_prefix) + 8 <= 63;
     }

   bool              Has(const string k) const { return GlobalVariableCheck(Key(k)); }
   double            Get(const string k, double def = 0.0) const { return GlobalVariableCheck(Key(k)) ? GlobalVariableGet(Key(k)) : def; }
   void              Set(const string k, double v)
     {
      if(GlobalVariableCheck(Key(k)) && GlobalVariableGet(Key(k)) == v)
         return;
      GlobalVariableSet(Key(k), v);
      m_dirty = true;
     }
   void              Del(const string k)
     {
      if(GlobalVariableDel(Key(k)))
         m_dirty = true;
     }
   void              Flush(void)
     {
      if(!m_dirty)
         return;
      GlobalVariablesFlush();
      m_dirty = false;
     }

   // Xóa mọi dữ liệu về lệnh (giữ vốn gốc, giới hạn lỗ, phanh, công tắc)
   void              ClearTrade(void)
     {
      string keys[] = {SK_POS, SK_POS_B, SK_POS_DIR, SK_POS_ZONE, SK_WANT_OPEN, SK_WANT_SL, SK_WANT_SL_ID, SK_IS_FLIP,
                       SK_FLIP, SK_FLIP_B, SK_REQ_KIND, SK_REQ_TIME, SK_REQ_TAG};
      for(int i = 0; i < ArraySize(keys); i++)
         Del(keys[i]);
     }

   // Chỉ xóa dữ liệu của lệnh vừa đóng; giữ dữ liệu lệnh chờ đảo và yêu cầu mở mới (có thể đang xảy ra cùng lúc)
   void              ClearPosition(void)
     {
      string keys[] = {SK_POS, SK_POS_B, SK_POS_DIR, SK_POS_ZONE, SK_WANT_OPEN, SK_WANT_SL, SK_WANT_SL_ID, SK_IS_FLIP};
      for(int i = 0; i < ArraySize(keys); i++)
         Del(keys[i]);
     }

   // Terminal tự xóa Global Variable sau 4 tuần không dùng: ghi lại mọi khóa của bot (gọi mỗi ngày một lần)
   void              Touch(void)
     {
      for(int i = GlobalVariablesTotal() - 1; i >= 0; i--)
        {
         string n = GlobalVariableName(i);
         if(StringFind(n, m_prefix) == 0)
            GlobalVariableSet(n, GlobalVariableGet(n));
        }
      GlobalVariablesFlush();
     }

   string            Prefix(void) const { return m_prefix; }
  };

#endif
