// ScpTypes.mqh — kiểu dữ liệu, hằng số và hàm dùng chung cho bot SCP-MTF-1.0.
// Nguồn luật: docs/SPEC.md mục 4, 5.3, 6.2, 9.4, 14.8.
// Không đọc dữ liệu, không gửi lệnh: file này chỉ định nghĩa kiểu và hàm thuần.
#ifndef SCP_TYPES_MQH
#define SCP_TYPES_MQH

#define SCP_SPEC_VERSION "SCP-MTF-1.3-review-fixes"

// ---------------------------------------------------------------- khung thời gian
// Thứ tự cố định dùng làm chỉ số mảng. D1 lớn nhất để vòng lặp khung lớn chạy ngược.
enum ENUM_SCP_TF
  {
   SCP_TF_M1 = 0,
   SCP_TF_M5 = 1,
   SCP_TF_M15 = 2,
   SCP_TF_H1 = 3,
   SCP_TF_H4 = 4,
   SCP_TF_D1 = 5,
   SCP_TF_COUNT = 6
  };

const ENUM_TIMEFRAMES SCP_TF_PERIODS[SCP_TF_COUNT] =
  {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1};

// ---------------------------------------------------------------- trạng thái và nhãn
enum ENUM_SCP_DIR
  {
   SCP_DIR_UNDEFINED = 0,   // chưa đủ cấu trúc
   SCP_DIR_UP = 1,
   SCP_DIR_DOWN = -1,
   SCP_DIR_TRANSITION = 2   // đã phá mốc bảo vệ, chưa xác lập hướng đối diện
  };

enum ENUM_SCP_ZONE_TYPE
  {
   SCP_ZONE_PIVOT = 0,   // hỗ trợ/kháng cự từ đỉnh đáy xác nhận
   SCP_ZONE_FVG = 1,
   SCP_ZONE_OB = 2,
   SCP_ZONE_MSNR = 3
  };

enum ENUM_SCP_ZONE_LEVEL
  {
   SCP_LEVEL_REFERENCE = 0,   // tham khảo yếu, chưa đủ hai phản ứng
   SCP_LEVEL_REACTION = 1,    // đã có hai phản ứng độc lập
   SCP_LEVEL_STRUCTURE = 2    // gắn với cấu trúc/đóng phá đã xác nhận
  };

enum ENUM_SCP_ROLE
  {
   SCP_ROLE_NEUTRAL = 0,
   SCP_ROLE_SUPPORT = 1,
   SCP_ROLE_RESISTANCE = -1
  };

enum ENUM_SCP_SIDE
  {
   SCP_SIDE_ABOVE = 1,   // giá tiếp cận vùng từ phía trên
   SCP_SIDE_BELOW = -1   // giá tiếp cận vùng từ phía dưới
  };

// Vòng đời một lần tiếp cận vùng (SPEC 6.2).
enum ENUM_SCP_EPISODE_STATE
  {
   SCP_EP_WATCHING = 0,
   SCP_EP_TOUCHED = 1,
   SCP_EP_WAIT_REACTION = 2,
   SCP_EP_REACTION_READY = 3,
   SCP_EP_BREAK_CANDIDATE = 4,
   SCP_EP_BREAK_CONFIRMED = 5,
   SCP_EP_RETEST_WAIT = 6,
   SCP_EP_RETEST_HELD = 7,
   SCP_EP_FAILED_BREAK = 8,
   SCP_EP_EXPIRED = 9,
   SCP_EP_CANCELLED = 10
  };

enum ENUM_SCP_REACTION
  {
   SCP_RE_NONE = 0,
   SCP_RE_P1 = 1,
   SCP_RE_P2 = 2,
   SCP_RE_P3 = 3,
   SCP_RE_P4 = 4,
   SCP_RE_P5 = 5
  };

enum ENUM_SCP_SCENARIO
  {
   SCP_SC_NONE = 0,
   SCP_SC_S01 = 1,
   SCP_SC_S02 = 2,
   SCP_SC_S03 = 3,
   SCP_SC_S04 = 4,
   SCP_SC_S05 = 5,
   SCP_SC_S06 = 6,
   SCP_SC_S07 = 7,
   SCP_SC_S08 = 8
  };

enum ENUM_SCP_CONTEXT
  {
   SCP_CTX_UNDEFINED = 0,
   SCP_CTX_WITH_LARGE = 1,
   SCP_CTX_COUNTER_LARGE = 2,
   SCP_CTX_MIXED = 3
  };

enum ENUM_SCP_THESIS
  {
   SCP_THESIS_NONE = 0,
   SCP_THESIS_LOCAL_REACTION = 1,   // chỉ đánh nhịp phản ứng con
   SCP_THESIS_ZONE_HOLD = 2,        // giữ cả vùng nguồn M1/M5
   SCP_THESIS_BREAK_HOLD = 3        // giữ phía mới sau phá/kiểm tra lại
  };

enum ENUM_SCP_EXEC_STATE
  {
   SCP_EX_IDLE = 0,
   SCP_EX_PLAN_READY = 1,
   SCP_EX_SENT_UNKNOWN = 2,
   SCP_EX_PARTIAL = 3,
   SCP_EX_FILLED = 4,
   SCP_EX_CLOSE_REQUESTED = 5,
   SCP_EX_CLOSED = 6,
   SCP_EX_REJECTED = 7
  };

// Lý do bỏ/hủy dùng chung để nhật ký đếm được.
enum ENUM_SCP_SKIP
  {
   SCP_SKIP_NONE = 0,
   SCP_SKIP_NO_DATA = 1,
   SCP_SKIP_SPREAD = 2,
   SCP_SKIP_NEWS = 3,
   SCP_SKIP_LOSS_LIMIT = 4,
   SCP_SKIP_HAS_POSITION = 5,
   SCP_SKIP_NO_TARGET = 6,
   SCP_SKIP_RR_LOW = 7,
   SCP_SKIP_STOP_TOO_FAR = 8,
   SCP_SKIP_STOP_TOO_CLOSE = 9,
   SCP_SKIP_VOLUME_MIN = 10,
   SCP_SKIP_TOO_FAR = 11,
   SCP_SKIP_STALE_SIGNAL = 12,
   SCP_SKIP_CONFLICT = 13,
   SCP_SKIP_SESSION_END = 14,
   SCP_SKIP_MARGIN = 15,
   SCP_SKIP_DUPLICATE = 16,
   SCP_SKIP_MONEY_CALC = 17
  };

// ---------------------------------------------------------------- dữ liệu nến
struct ScpBar
  {
   datetime          open_time;
   datetime          close_time;
   double            o, h, l, c;
   long              tick_volume;
   datetime          known_at;      // giờ nhận đầu tiên (mili giây nếu có)
   uint              received_mono; // đồng hồ nhận nến, 0 nếu dữ liệu kiểm không có
   int               known_at_msc;  // phần mili giây đã quan sát; -1 là không rõ
   bool              complete;      // dữ liệu nến đủ hợp lệ
  };

struct ScpQuote
  {
   double            bid, ask;
   datetime          time;          // giờ sàn
   datetime          received_at;   // giờ máy nhận
   uint              received_msc;  // số mili giây đơn điệu lúc nhận
   long              broker_msc;
  };

// ---------------------------------------------------------------- cấu trúc khung
struct ScpPivot
  {
   long              id;
   bool              is_high;
   double            price;
   datetime          bar_time;      // nến tạo pivot
   datetime          known_at;      // lúc nến xác nhận cuối đóng
   bool              ambiguous;     // cùng nến là cả đỉnh và đáy
   bool              used;          // đã tham gia cặp cấu trúc
  };

struct ScpFrameInfo
  {
   ENUM_SCP_DIR      dir;
   long              protected_pivot_id;
   datetime          last_closed_at;
   datetime          known_at;
   bool              data_ok;
   double            atr;           // ATR(14) nến đã đóng cuối
  };

// ---------------------------------------------------------------- vùng giá
struct ScpZone
  {
   long              id;
   int               version;
   ENUM_SCP_ZONE_TYPE type;
   ENUM_SCP_ZONE_LEVEL level;
   ENUM_SCP_TF       source_tf;
   double            bottom, top;
   ENUM_SCP_ROLE     source_role;
   datetime          origin_time;
   datetime          known_at;
   bool              is_point;      // hai biên bằng nhau
   int               independent_touches;
   int               reaction_count;
   datetime          last_touch;
   datetime          expires_at;
   bool              broken_up;     // đã có B0_UP
   bool              broken_down;
   datetime          broken_up_at;
   datetime          broken_down_at;
   long              evidence_id;   // pivot/event gốc
   bool              alive;         // còn dùng được (chưa hết tuổi/hết dữ liệu)
  };

// Một lần tiếp cận vùng theo cặp (zone, khung giao dịch).
struct ScpEpisode
  {
   long              id;
   long              cluster_id;     // gom M1/M5 cùng một sự kiện để chống trùng
   long              zone_id;
   ENUM_SCP_TF       entry_tf;
   ENUM_SCP_EPISODE_STATE state;
   ENUM_SCP_SIDE     approach_side;
   ENUM_SCP_ROLE     local_role;     // vai trò cục bộ trên khung giao dịch
   int               role_version;
   datetime          touch_at;
   datetime          opened_at;
   datetime          deadline;       // hạn phản ứng
   datetime          last_event_at;
   double            atr_ref;        // ATR khung giao dịch đóng cuối trước episode
   double            eps_geom;
   double            ext_low, ext_high;    // cực trị đã thấy trong episode
   double            invalidation;   // mốc làm nhịp phản ứng sai
   double            pivot_small;    // đỉnh/đáy nhỏ cho P3; 0 là không có
   bool              small_is_high;
   double            zone_bottom, zone_top; // hình học đóng băng
   double            edge_touched;   // mép vùng bị chạm (T khi mua, B khi bán)
   bool              frozen;         // episode đã đóng băng hình học
   int               last_reaction;  // ENUM_SCP_REACTION gần nhất
   datetime          reaction_at;
   long              last_break_id;  // sự kiện phá gần nhất của episode
   bool              provisional;    // xác nhận trong nến
  };

struct ScpBreakEvent
  {
   long              id;
   long              zone_id;
   ENUM_SCP_TF       break_tf;
   int               direction;      // +1 phá lên, -1 phá xuống
   datetime          bar_time;
   datetime          known_at;
   double            edge_bid;
   bool              is_p4;
   double            invalidation;
   bool              failed;         // đã quay lại phía cũ
   bool              consumed;       // đã dùng để phát đề nghị
   double            bar_low, bar_high, bar_close;
   double            atr_ref, eps_geom;
   bool              confirmed; // false: râu xuyên chưa có đóng phá
   datetime          used_at[9];
  };

struct ScpReactionInfo
  {
   ENUM_SCP_REACTION kind;
   int               direction;
   long              zone_id;
   long              episode_id;
   datetime          known_at;
   bool              provisional;
   double            ext_low, ext_high;
   double            atr_ref;
   double            eps_geom;
  };

// Đề nghị giao dịch do một nhánh phát ra, chưa phải kế hoạch gửi (SPEC mục 8, 9.2).
struct ScpProposal
  {
   ENUM_SCP_SCENARIO scenario;
   long              zone_id;
   long              episode_id;
   ENUM_SCP_TF       entry_tf;
   ENUM_SCP_TF       management_tf;
   int               direction;
   ENUM_SCP_THESIS   thesis;
   ENUM_SCP_CONTEXT  context;
   ENUM_SCP_REACTION reaction;
   datetime          reaction_known_at;
   uint              reaction_mono;
   double            reaction_bid, confirmation_edge, atr_m1;
   long              reaction_key;
   bool              provisional;
   double            invalidation;
   long              target_zone_id;
   double            target_edge;
   double            atr_ref;
   long              break_id;       // sự kiện phá nguồn (nhánh S05/S06/S07)
   string            why;
  };

// Bối cảnh từng khung tại thời điểm quyết định.
struct ScpContextSnapshot
  {
   ENUM_SCP_DIR      d1, h4, h1, m15, m5, m1;
  };

// ---------------------------------------------------------------- kế hoạch giao dịch
struct ScpPlan
  {
   long              plan_id;
   string            spec_version;
   string            parameter_hash;
   string            symbol;
   long              episode_id;
   ENUM_SCP_SCENARIO scenario;
   long              zone_id;
   ENUM_SCP_TF       entry_tf;
   ENUM_SCP_TF       management_tf;
   int               direction;
   ENUM_SCP_CONTEXT  context;
   ENUM_SCP_THESIS   thesis;
   datetime          reaction_known_at;
   datetime          sent_at;
   uint              reaction_mono;
   double            reaction_bid, confirmation_edge, atr_m1, risk_budget;
   int               hold_seconds, progress_seconds;
   bool              provisional;
   double            entry_price_limit;
   double            invalidation;
   double            sl;
   double            tp;
   long              target_zone_id;
   double            target_edge_bid; // hình học cản, không phải mức TP Bid/Ask đã trừ đệm
   double            expected_cost;
   double            expected_risk;
   double            expected_reward;
   double            net_reward_risk;
   double            volume;
   double            atr_ref;
   datetime          send_deadline;
   datetime          hold_deadline;
   datetime          no_progress_deadline;
   bool              market_only;
   double            partial_volume;       // phần chốt đầu, 0 nếu không chia được/TP tới trước
   double            partial_trigger;      // khoảng đi thuận theo giá thoát được
   double            breakeven_trigger;
  };

struct ScpPosition
  {
   long              plan_id;
   ulong             position_id;
   ulong             order_id;
   ulong             deal_id;
   ENUM_SCP_EXEC_STATE state;
   string            symbol;
   int               direction;
   double            volume;
   double            entry_price;
   double            sl;
   double            tp;
   datetime          opened_at;
   datetime          hold_deadline;
   datetime          no_progress_deadline;
   double            mfe;            // mức đi thuận lớn nhất theo giá thoát được
   double            mae;
   double            atr_ref;
   double            risk_money;
   bool              sl_confirmed;
   bool              tp_confirmed;
   ENUM_SCP_THESIS   thesis;
   ENUM_SCP_SCENARIO scenario;
   ENUM_SCP_TF       entry_tf;
   ENUM_SCP_CONTEXT  context;
  };

// ---------------------------------------------------------------- hàm thuần dùng chung

double ScpHalfVolume(double initial,double minimum,double step)
  {
   if(initial<=0.01+1e-9 || minimum<=0 || step<=0) return 0;
   double close=NormalizeDouble(MathFloor((initial*0.5+1e-10)/step)*step,8);
   double remain=NormalizeDouble(initial-close,8);
   if(close<minimum-1e-9 || remain<minimum-1e-9) return 0;
   return close;
  }

bool ScpEntryStop(int dir,double entry,double exit_price,double current_sl,double trigger,
                  double tick,double min_distance,double &new_sl)
  {
   if((dir!=1 && dir!=-1) || trigger<=0 || tick<=0 || dir*(exit_price-entry)<trigger-1e-9) return false;
   new_sl=dir>0 ? ScpRoundUpToTick(entry,tick) : ScpRoundDownToTick(entry,tick);
   if(current_sl>0 && dir*(new_sl-current_sl)<=tick*0.5) return false;
   return dir*(exit_price-new_sl)>min_distance+tick*0.5;
  }

bool ScpCanStart(ENUM_SCP_EXEC_STATE state)
  {
   return state == SCP_EX_IDLE || state == SCP_EX_CLOSED || state == SCP_EX_REJECTED;
  }

// Dấu của một số; 0 giữ nguyên 0.
int ScpSign(double v)
  {
   if(v > 0.0)
      return 1;
   if(v < 0.0)
      return -1;
   return 0;
  }

// Làm tròn giá theo bước giá. SL làm tròn ra xa giá vào, TP làm tròn về phía chốt sớm hơn.
double ScpRoundDownToTick(double price, double tick)
  {
   if(tick <= 0.0)
      return price;
   return NormalizeDouble(MathFloor(price / tick + 1e-9) * tick, 8);
  }

double ScpRoundUpToTick(double price, double tick)
  {
   if(tick <= 0.0)
      return price;
   return NormalizeDouble(MathCeil(price / tick - 1e-9) * tick, 8);
  }

double ScpRoundNear(double price, double tick)
  {
   if(tick <= 0.0)
      return price;
   return NormalizeDouble(MathRound(price / tick) * tick, 8);
  }

bool ScpBetween(double v, double a, double b)
  {
   double lo = MathMin(a, b), hi = MathMax(a, b);
   return (v >= lo && v <= hi);
  }

string ScpDirName(ENUM_SCP_DIR d)
  {
   switch(d)
     {
      case SCP_DIR_UP:
         return "UP";
      case SCP_DIR_DOWN:
         return "DOWN";
      case SCP_DIR_TRANSITION:
         return "TRANSITION";
     }
   return "UNDEFINED";
  }

string ScpScenarioName(ENUM_SCP_SCENARIO s)
  {
   switch(s)
     {
      case SCP_SC_S01:
         return "S01";
      case SCP_SC_S02:
         return "S02";
      case SCP_SC_S03:
         return "S03";
      case SCP_SC_S04:
         return "S04";
      case SCP_SC_S05:
         return "S05";
      case SCP_SC_S06:
         return "S06";
      case SCP_SC_S07:
         return "S07";
      case SCP_SC_S08:
         return "S08";
     }
   return "NONE";
  }

string ScpContextName(ENUM_SCP_CONTEXT c)
  {
   switch(c)
     {
      case SCP_CTX_WITH_LARGE:
         return "WITH_LARGE";
      case SCP_CTX_COUNTER_LARGE:
         return "COUNTER_LARGE";
      case SCP_CTX_MIXED:
         return "MIXED";
     }
   return "UNDEFINED";
  }

string ScpTfName(ENUM_SCP_TF tf)
  {
   switch(tf)
     {
      case SCP_TF_M1:
         return "M1";
      case SCP_TF_M5:
         return "M5";
      case SCP_TF_M15:
         return "M15";
      case SCP_TF_H1:
         return "H1";
      case SCP_TF_H4:
         return "H4";
      case SCP_TF_D1:
         return "D1";
     }
   return "?";
  }

string ScpSkipName(ENUM_SCP_SKIP r)
  {
   switch(r)
     {
      case SCP_SKIP_NONE:
         return "NONE";
      case SCP_SKIP_NO_DATA:
         return "NO_DATA";
      case SCP_SKIP_SPREAD:
         return "SPREAD_SPIKE";
      case SCP_SKIP_NEWS:
         return "NEWS_WINDOW";
      case SCP_SKIP_LOSS_LIMIT:
         return "LOSS_LIMIT";
      case SCP_SKIP_HAS_POSITION:
         return "HAS_POSITION";
      case SCP_SKIP_NO_TARGET:
         return "NO_TARGET";
      case SCP_SKIP_RR_LOW:
         return "RR_LOW";
      case SCP_SKIP_STOP_TOO_FAR:
         return "STOP_TOO_FAR";
      case SCP_SKIP_STOP_TOO_CLOSE:
         return "STOP_TOO_CLOSE";
      case SCP_SKIP_VOLUME_MIN:
         return "VOLUME_BELOW_MIN";
      case SCP_SKIP_TOO_FAR:
         return "PRICE_TOO_FAR";
      case SCP_SKIP_STALE_SIGNAL:
         return "STALE_SIGNAL";
      case SCP_SKIP_CONFLICT:
         return "CONFLICT";
      case SCP_SKIP_SESSION_END:
         return "SESSION_END";
      case SCP_SKIP_MARGIN:
         return "MARGIN";
      case SCP_SKIP_DUPLICATE:
         return "DUPLICATE";
      case SCP_SKIP_MONEY_CALC:
         return "MONEY_CALC";
     }
   return "SKIP";
  }

#endif // SCP_TYPES_MQH
