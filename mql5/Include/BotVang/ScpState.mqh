// ScpState.mqh — lưu bền trạng thái bot bằng Global Variables của terminal (SPEC mục 12, 14.8).
// Tên khóa: SCP_<login>_<server>_<symbol>_<magic>_<khóa>. Không ghi mật khẩu hay thông tin tài khoản khác.
#ifndef SCP_STATE_MQH
#define SCP_STATE_MQH


#define SK_CAP          "cap"       // vốn tham chiếu tổng
#define SK_CAP_TIME     "capT"      // lúc đặt vốn tham chiếu
#define SK_DAY_REF      "dayRef"    // vốn đầu ngày
#define SK_DAY_KEY      "dayKey"
#define SK_WEEK_REF     "wkRef"
#define SK_WEEK_KEY     "wkKey"
#define SK_LOCK_UNTIL   "lockTo"    // khóa mở mới tới lúc nào (0 là không khóa)
#define SK_LOCK_WHY     "lockWhy"
#define SK_PLAN_ID      "planId"    // kế hoạch đang gửi/đang quản lý
#define SK_PLAN_DB      "planDb"    // bản ghi kế hoạch (chuỗi nén)
#define SK_EXEC_STATE   "execSt"
#define SK_POS_ID       "posId"
#define SK_POS_SL       "posSl"
#define SK_POS_TP       "posTp"
#define SK_POS_VOL      "posVol"
#define SK_POS_DIR      "posDir"
#define SK_POS_ENTRY    "posEn"
#define SK_POS_OPEN     "posOp"
#define SK_POS_HOLD     "posHold"
#define SK_POS_PROG     "posProg"
#define SK_POS_ATR      "posAtr"
#define SK_POS_MFE      "posMfe"
#define SK_POS_INVAL    "posInval"
#define SK_POS_R0       "posR0"     // khoảng dừng ban đầu (giá) lúc gửi
#define SK_POS_TGT      "posTgt"
#define SK_POS_PLAN     "posPlan"
#define SK_ORDER        "order"
#define SK_POS_IDENT    "posIdent"
#define SK_RISK_BUDGET  "riskBudget"
#define SK_RISK_COST    "riskCost"
#define SK_HOLD_SEC     "holdSec"
#define SK_PROG_SEC     "progSec"
#define SK_LAST_CLOSE   "lastClose"
#define SK_LOCK_DAY     "lockDay"
#define SK_LOCK_WEEK    "lockWeek"
#define SK_LOCK_TOTAL   "lockTotal"
#define SK_SEQ          "seq"
#define SK_SCALE_STATE  "scaleSt"     // 0 chưa gửi, 1 chưa rõ, 2 đã giảm, 3 bị từ chối
#define SK_SCALE_VOL    "scaleVol"
#define SK_SCALE_AT     "scaleAt"
#define SK_BE_AT        "beAt"

class ScpState
  {
private:
   string            m_prefix;
   bool              m_dirty;
   bool              m_healthy;
   long              m_login;
   string            m_server;
   string            m_symbol;
   long              m_magic;

   string            Key(const string k) { return m_prefix + k; }

public:
   bool              Init(const string sym, long magic)
     {
      m_login = AccountInfoInteger(ACCOUNT_LOGIN);
      m_server = AccountInfoString(ACCOUNT_SERVER);
      m_symbol = sym;
      m_magic = magic;
      m_prefix = "SCP_" + (string)m_login + "_" + m_server + "_" + sym + "_" + (string)magic + "_";
      int over = StringLen(m_prefix) + 10 - 63;
      if(over > 0)
         m_prefix = "SCP_" + (string)m_login + "_" + StringSubstr(m_server, 0, MathMax(1, StringLen(m_server) - over)) +
                    "_" + sym + "_" + (string)magic + "_";
      m_dirty = false;
      m_healthy = (StringLen(m_prefix) + 10 <= 63);
      return (StringLen(m_prefix) + 10 <= 63);
     }

   bool              Healthy() { return m_healthy; }

   bool              Has(const string k) { return GlobalVariableCheck(Key(k)); }
   double            Get(const string k, double def = 0.0) { return GlobalVariableCheck(Key(k)) ? GlobalVariableGet(Key(k)) : def; }
   void              Set(const string k, double v)
     {
      if(GlobalVariableCheck(Key(k)) && GlobalVariableGet(Key(k)) == v)
         return;
      if(GlobalVariableSet(Key(k), v) == 0)
        { m_healthy = false; Print("[SCP][STATE] không lưu được khóa ", k, " lỗi ", GetLastError()); }
      m_dirty = true;
     }
   void              Flush()
     {
      if(m_dirty)
        {
         GlobalVariablesFlush();
         m_dirty = false;
        }
     }

  };

#endif // SCP_STATE_MQH
