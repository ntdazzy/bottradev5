// Kiểu dữ liệu dùng chung của BotVang (SPEC v2)
#ifndef BOTVANG_TYPES_MQH
#define BOTVANG_TYPES_MQH

enum ENUM_FLIP_MODE   { FLIP_OFF = 0, FLIP_CONDITIONAL = 1 };
enum ENUM_BIAS_MODE   { BIAS_H4_H1 = 0, BIAS_H1_ONLY = 1, BIAS_H4_ONLY = 2 };
enum ENUM_LIMIT_UNIT  { LIMIT_PERCENT = 0, LIMIT_USD = 1 };
enum ENUM_ZONE_KIND   { ZK_AV = 0, ZK_GAP = 1, ZK_SWING = 2, ZK_PREVDAY = 3 };
// Trạng thái bot (§15): CHỜ / ĐANG CHẠY / TẠI CẢN / NGHỈ / ĐANG ĐÓNG / KHÔI PHỤC / DỪNG HẲN
enum ENUM_BOT_STATE   { ST_WAIT = 0, ST_RUN = 1, ST_AT_ZONE = 2, ST_PAUSE = 3, ST_CLOSING = 4, ST_RECOVERY = 5, ST_STOPPED = 6 };

// Cài đặt của bot giao dịch (SPEC §2, §7–§14). Giá trị mặc định đặt ở BotVang.mq5.
struct BotSettings
  {
   long              magic;
   double            lot;
   bool              allowFresh;          // tùy chọn §7.1: vào cả vùng còn mới chưa lật
   ENUM_BIAS_MODE    biasMode;
   int               minEntryScore;
   int               strongScore;
   double            minRoomB;
   double            stepAtrMult;
   double            stepMinSpreadMult;
   double            lockDistB;           // §9: giá cách mép cản < lockDistB × B thì khóa lời
   double            lockOffsetB;         // dừng lỗ cách giá lockOffsetB × B
   int               maxBarsInZone;       // §9: nằm trong dải cản quá số nến này thì không đảo
   int               brakeLosses;         // §10: số lần dừng lỗ lỗ tiền liên tiếp thì NGHỈ
   int               brakeMinutes;
   double            riskPct;             // §11.1
   double            slipBuffer;          // đệm trượt giá theo giá (§11.1)
   ENUM_LIMIT_UNIT   limitUnit;
   double            dayLoss;
   double            weekLoss;
   double            totalLoss;
   bool              profitTargetOn;
   double            dayProfit;
   double            weekProfit;
   double            minFreeMarginPct;    // §11.4
   double            minMarginLevel;
   int               newsBefore;
   int               newsAfter;
   int               fomcAfter;
   double            maxEntrySlipB;       // §13.3: trượt khi vào > x × B thì đóng ngay và NGHỈ
   double            maxSlSlipB;          // trượt khi dính dừng lỗ > x × B thì NGHỈ
   int               slipPauseMinutes;
  };

// Kết quả cập nhật một vùng trên một nến M5 đã đóng (cộng dồn bit)
#define ZEV_TOUCH       1    // một lần chạm mới (§5.3)
#define ZEV_FIRST_TOUCH 2    // lần chạm đầu đúng §5.4
#define ZEV_BOUNCE      4    // bật thật (§5.3)
#define ZEV_FLIP        8    // bị phá lần đầu, lật vai
#define ZEV_DEAD        16   // bị phá lần hai, xóa
#define ZEV_FLIP_FAILED 32   // [ỨNG VIÊN] lật thất bại

// Luật vùng. Giá trị mặc định = luật [GỐC]; các trường [ỨNG VIÊN] tắt khi bằng 0/false.
struct ZoneRules
  {
   double            awayAtr;             // [GỐC] 1,0: phải rời >= awayAtr × biến động khung vùng rồi mới tính lần chạm mới
   bool              flipNeedsAway;       // [GỐC] đúng chữ §5.3: sau lật cũng phải rời xa rồi mới tính chạm; false = biến thể "chạm ngay" (code bản 1)
   int               minTouchGapBars;     // [ỨNG VIÊN] 10: hai lần chạm cách nhau >= số nến M5 này
   double            retestAwayAtrM5;     // [ỨNG VIÊN] 0,34: sau lật chỉ cần rời >= x × ATR(M5) (thay cho awayAtr)
   int               retestMinBars;       // [ỨNG VIÊN] 2: sau lật phải qua ít nhất số nến này mới tính chạm
   int               failedFlipBars;      // [ỨNG VIÊN] 1–2: trong số nến này sau lật, nến đóng quay lại dải → hủy lật
   bool              gapBaseBreakout;     // [ỨNG VIÊN] lọc Gap kiểu "đế + thoát"
   int               expireM15Hours;      // [ỨNG VIÊN] 24–48: vùng M15 hết hạn
   int               expireHtfDays;       // [ỨNG VIÊN] 7 ngày lịch (≈ 5 ngày giao dịch) cho H1/H4/ngày
   int               maxPerTf;            // [GỐC] 60 vùng mỗi khung
   double            farAtrH1;            // [GỐC] 40: xóa vùng cách giá > 40 × ATR(H1)
  };

void ZoneRulesDefault(ZoneRules &r)
  {
   r.awayAtr = 1.0;
   r.flipNeedsAway = true;
   r.minTouchGapBars = 0;
   r.retestAwayAtrM5 = 0.0;
   r.retestMinBars = 0;
   r.failedFlipBars = 0;
   r.gapBaseBreakout = false;
   r.expireM15Hours = 0;
   r.expireHtfDays = 0;
   r.maxPerTf = 60;
   r.farAtrH1 = 40.0;
  }

struct Zone
  {
   int               id;
   int               parent;             // -1: vùng thật; >= 0: id vùng thật đã sinh ra vùng giả này
   double            level;
   double            lo;
   double            hi;
   bool              isRes;              // vai hiện tại: true = kháng cự
   ENUM_TIMEFRAMES   tf;                 // PERIOD_D1 = đỉnh/đáy ngày hôm trước
   ENUM_ZONE_KIND    kind;
   double            atr;                // biến động (ATR 14) của khung tạo vùng lúc tạo
   datetime          created;            // lúc nến xác nhận vùng đã đóng
   datetime          flipTime;           // lúc lật vai (0 = chưa lật)
   int               flips;              // 0 hoặc 1
   bool              flipFailed;         // [ỨNG VIÊN] lật thất bại: không dùng để vào lệnh
   int               touches;            // số lần chạm kể từ lúc tạo hoặc lúc lật
   int               bounces;            // số lần bật thật kể từ lúc tạo hoặc lúc lật
   int               bouncesBeforeFlip;
   bool              away;               // giá đã rời đủ xa kể từ lúc tạo/lật/lần chạm trước
   bool              inTouch;            // đang trong một lần chạm, chưa bật ra
   datetime          lastTouch;
   int               barsSinceFlip;      // số nến M5 đã đóng kể từ lúc lật
   int               barsAlive;          // số nến M5 đã đóng kể từ lúc tạo (đếm nến thật, không đếm giờ nghỉ)
   int               copy;               // vùng giả: bản sao thứ mấy của vùng thật mẹ (1..n); vùng thật: 0
   int               barsInside;         // số nến M5 liền nhau có râu trong dải
   bool              strongOrigin;       // tạo bởi nến thân >= 1,5 × biến động
   bool              dead;
   int               score;              // điểm sức mạnh §6.1, tính lại sau mỗi nến M5
  };

#endif
