// ScpVerify.mq5 — chạy các ca kiểm tra của bot SCP-MTF-1.0.
// Nguồn luật: docs/SPEC.md mục 17 (AC01–AC41). Không gửi lệnh, không đọc tài khoản.
// Chạy: powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-script.ps1 -Script BotVang\ScpVerify -Period M1
#property script_show_inputs

#include <BotVang\ScpTypes.mqh>
#include <BotVang\ScpSeries.mqh>
#include <BotVang\ScpZones.mqh>
#include <BotVang\ScpEpisodes.mqh>
#include <BotVang\ScpReaction.mqh>
#include <BotVang\ScpScenario.mqh>
#include <BotVang\ScpPlan.mqh>
#include <BotVang\ScpManage.mqh>

// Nguồn tiền giả để kiểm công thức không cần sàn: 1 lot = 100 đơn vị giá.
class ScpFakeMoney : public ScpMoneySource
  {
public:
   double            contract;
   double            equity;
   double            freeMargin;
   bool              connected;
                     ScpFakeMoney() { contract = 100.0; equity = 10000.0; freeMargin = 10000.0; connected = true; }
   virtual bool      Profit(int dir, double volume, double entry, double exit, double &money)
     {
      double diff = (dir > 0) ? (exit - entry) : (entry - exit);
      money = diff * volume * contract;
      return true;
     }
   virtual bool      Margin(int dir, double volume, double price, double &money)
     {
      money = volume * contract * price * 0.01;
      return true;
     }
   virtual double    Equity() { return equity; }
   virtual double    FreeMargin() { return freeMargin; }
   virtual bool      Connected() { return connected; }
  };

input bool   InpCloseTerminal = false;   // run-script.ps1 tự đặt true
input string InpOnly          = "";      // rỗng = chạy hết; Ví dụ "AC21" chỉ chạy nhóm đó
input bool   InpVerbose       = true;

int    g_pass = 0;
int    g_fail = 0;
string g_failList = "";
int    g_run = 0;
ScpFrames      SFR;
ScpZoneMap    SZN, SZN2;
ScpEpisodeMap SEP, SEP2;

void Ac(bool cond, string id, string name, string detail = "")
  {
   if(InpOnly != "" && StringFind(id, InpOnly) != 0)
      return;
   g_run++;
   if(cond)
     {
      g_pass++;
      if(InpVerbose)
         Print("PASS ", id, " — ", name);
     }
   else
     {
      g_fail++;
      g_failList += id + " | " + name + (detail == "" ? "" : " | " + detail) + "\n";
      Print("FAIL ", id, " — ", name, (detail == "" ? "" : " | " + detail));
     }
  }

ScpBar MkBar(datetime open_time, double o, double h, double l, double c, int period_sec = 60)
  {
   ScpBar b;
   ZeroMemory(b);
   b.open_time = open_time;
   b.close_time = open_time + period_sec;
   b.o = o;
   b.h = h;
   b.l = l;
   b.c = c;
   b.tick_volume = 10;
   b.known_at = b.close_time;
   b.known_at_msc = -1;
   b.complete = true;
   return b;
  }

// ------------------------------------------------------------------ ca kiểm tra nền

void TestPivotConfirmation()
  {
   ScpSeries s;
   s.Init(SCP_TF_M1);
   datetime t0 = D'2026.01.05 00:00';
   // 6 nến đầu đi ngang; nến thứ 7 (chỉ số 5) là đỉnh nhọn.
   double base = 100.0;
   s.PushBar(MkBar(t0, base, base + 0.5, base - 0.5, base));
   s.PushBar(MkBar(t0 + 60, base, base + 0.5, base - 0.5, base));
   s.PushBar(MkBar(t0 + 120, base, base + 0.5, base - 0.5, base));
   s.PushBar(MkBar(t0 + 180, base, base + 0.5, base - 0.5, base));
   s.PushBar(MkBar(t0 + 240, base, base + 0.5, base - 0.5, base));
   s.PushBar(MkBar(t0 + 300, base, base + 3.0, base - 0.5, base + 1.0));   // đỉnh nhọn
   int before = s.PivotCount();
   Ac(before == 0, "AC21a", "pivot chưa công bố khi chưa đủ N nến bên phải",
      "pivot_count=" + IntegerToString(before));
   s.PushBar(MkBar(t0 + 360, base, base + 1.0, base - 0.5, base));
   int mid = s.PivotCount();
   Ac(mid == 0, "AC21b", "pivot vẫn chưa công bố sau 1 nến bên phải",
      "pivot_count=" + IntegerToString(mid));
   s.PushBar(MkBar(t0 + 420, base, base + 1.0, base - 0.5, base));
   int after = s.PivotCount();
   Ac(after >= 1, "AC21c", "pivot công bố sau đủ N nến bên phải",
      "pivot_count=" + IntegerToString(after));
   if(after >= 1)
     {
      ScpPivot p = s.Pivot(0);
      Ac(p.is_high && MathAbs(p.price - (base + 3.0)) < 1e-9,
         "AC21d", "pivot ghi đúng đỉnh và loại đỉnh", "price=" + DoubleToString(p.price, 3));
     }
  }

void PushSeg(ScpSeries &s, datetime &t, double price, int n, int period_sec = 60)
  {
   for(int i = 0; i < n; i++)
     {
      s.PushBar(MkBar(t, price, price + 0.2, price - 0.2, price, period_sec));
      t += period_sec;
     }
  }

void TestDirectionAndTransition()
  {
   ScpSeries s;
   s.Init(SCP_TF_M1);
   datetime t = D'2026.01.05 00:00';
   // Zigzag tăng: đáy 99,8 → 100,3 → 101,3 và đỉnh 101,2 → 102,2.
   PushSeg(s, t, 100.0, 3);
   PushSeg(s, t, 101.0, 3);
   PushSeg(s, t, 100.5, 3);
   PushSeg(s, t, 102.0, 3);
   PushSeg(s, t, 101.5, 3);
   ENUM_SCP_DIR dir = s.Dir();
   double prot = s.ProtectedPrice();
   Ac(dir == SCP_DIR_UP,
      "AC21e", "cấu trúc đỉnh/đáy cao dần cho hướng UP",
      "dir=" + ScpDirName(dir) + " pivots=" + IntegerToString(s.PivotCount()));
   Ac(prot > 0.0 && MathAbs(prot - 100.3) < 0.11,
      "AC21f", "chưa có lần phá đỉnh thì mốc bảo vệ là đáy của cặp cấu trúc",
      "prot=" + DoubleToString(prot, 3));
   // Đóng phá xuống dưới mốc bảo vệ phải chuyển TRANSITION, không lập tức DOWN.
   s.PushBar(MkBar(t, 100.8, 100.9, 99.7, 99.9));
   Ac(s.Dir() == SCP_DIR_TRANSITION,
      "AC21g", "đóng phá mốc bảo vệ chuyển TRANSITION, không nhảy DOWN ngay",
      "dir=" + ScpDirName(s.Dir()) + " prot=" + DoubleToString(prot, 3));
  }

void TestEmaSeed()
  {
   ScpSeries s;
   s.Init(SCP_TF_M5);
   datetime t = D'2026.01.05 00:00';
   for(int i = 0; i < 60; i++)
      s.PushBar(MkBar(t + (datetime)(i * 300), 100.0, 100.5, 99.5, 100.0, 300));
   Ac(!s.EmaReady(200), "AC15a", "EMA200 chưa đủ lịch sử thì báo chưa sẵn sàng",
      "count=" + IntegerToString(s.Count()));
   s.PushBar(MkBar(t + 60 * 300, 100.0, 100.5, 99.5, 100.0, 300));
   Ac(s.EmaReady(20) && s.EmaReady(50), "AC15b", "EMA20/50 đủ lịch sử thì dùng được",
      "count=" + IntegerToString(s.Count()));
   double atr = s.Atr();
   Ac(atr > 0.0, "AC15c", "ATR tính được từ nến đã đóng", "atr=" + DoubleToString(atr, 3));
  }

// ------------------------------------------------------------------ vùng và episode

ScpBar ZoneBar(datetime t, double o, double h, double l, double c, int sec = 60)
  {
   return MkBar(t, o, h, l, c, sec);
  }

void TestZoneAndEpisode()
  {
   SZN.Init();
   datetime t = D'2026.01.05 00:00';
   // Vùng hỗ trợ M1 [100.0; 100.4] từ một nến "pivot" giả lập.
   ScpBar zb = ZoneBar(t, 100.6, 100.7, 100.0, 100.4);
   long zid = SZN.AddFromPivot(SCP_TF_M1, zb, false, t + 60, 1.0, 0.01);
   ScpZone z;
   Ac(zid > 0 && SZN.Find(zid, z) && MathAbs(z.bottom - 100.0) < 1e-9 && MathAbs(z.top - 100.4) < 1e-9,
      "Z01", "vùng hỗ trợ từ pivot đúng [L, min(O,C)]",
      "b=" + DoubleToString(z.bottom, 2) + " t=" + DoubleToString(z.top, 2));

   SEP.Init();
   double eps_g = 0.10;
   // Tiếp cận từ phía sai (giá dưới vùng đi lên) không được mở episode mua tại hỗ trợ.
   SEP.Watch(z, 99.5, eps_g, t + 120, SCP_TF_M1, 1.0, 0, 101.2, 100.3);
   long wrong = SEP.Watch(z, 100.2, eps_g, t + 130, SCP_TF_M1, 1.0, 0, 101.2, 100.3);
   Ac(wrong == 0, "AC-E1", "vào vùng từ phía sai không mở episode",
      "id=" + IntegerToString((int)wrong));
   // Tiếp cận đúng phía: từ trên đi xuống.
   SEP.Watch(z, 101.2, eps_g, t + 200, SCP_TF_M1, 1.0, 0, 101.2, 100.3);
   long ok = SEP.Watch(z, 100.2, eps_g, t + 210, SCP_TF_M1, 1.0, 0, 101.2, 100.3);
   Ac(ok > 0, "AC-E2", "tiếp cận đúng phía mở episode tại vùng",
      "id=" + IntegerToString((int)ok));
   ScpEpisode ep;
   Ac(SEP.ById(ok, ep) && ep.local_role == SCP_ROLE_SUPPORT && ep.approach_side == SCP_SIDE_ABOVE,
      "AC-E3", "episode ghi đúng vai trò cục bộ và phía tiếp cận", "");
   // Chưa rời vùng thì không mở episode mới.
   long dup = SEP.Watch(z, 100.3, eps_g, t + 220, SCP_TF_M1, 1.0, 0, 101.2, 100.3);
   Ac(dup == 0, "AC-E4", "chưa rời vùng thì không mở episode trùng", "");
   // Nến đóng hoàn toàn rời vùng rồi quay lại thì được tiếp cận mới.
   ScpBar left = MkBar(t + 240, 100.9, 101.0, 100.7, 100.8);
   SEP.OnBarClosed((int)SCP_TF_M1, left, SZN, eps_g, t + 300);
   SEP.Watch(z, 101.1, eps_g, t + 360, SCP_TF_M1, 1.0, 0, 101.2, 100.3);
   long again = SEP.Watch(z, 100.1, eps_g, t + 400, SCP_TF_M1, 1.0, 0, 101.2, 100.3);
   Ac(again > 0 && again != ok, "AC-E5", "rời vùng bằng một nến đóng rồi quay lại được episode mới",
      "id=" + IntegerToString((int)again));
  }

// ------------------------------------------------------------------ phản ứng

void TestReactionPatterns()
  {
   // V01: hỗ trợ [99,80;100,20], nến M1 O=100,50 H=100,60 L=99,60 C=100,55, ATR=1,00.
   ScpBar v01 = MkBar(D'2026.01.05 10:00', 100.50, 100.60, 99.60, 100.55);
   Ac(ScpP1(v01, +1, 99.80, 100.20, 1.00, true),
      "AC16a", "P1 mua đủ râu, vị trí đóng và giữ phía trên vùng (V01)", "");
   // V03: râu 0,35 < 0,5 ATR nên P1 chưa đủ.
   ScpBar v03 = MkBar(D'2026.01.05 10:01', 102.50, 102.60, 102.15, 102.55);
   Ac(!ScpP1(v03, +1, 102.10, 102.30, 1.00, true),
      "AC16b", "râu ngắn hơn 0,5 ATR không thành P1 (V03)", "");
   // P2 mua: nến trước đỏ, nến sau xanh bao phủ thân và đóng trên mép vùng.
   ScpBar p2a = MkBar(D'2026.01.05 10:02', 100.90, 101.00, 100.10, 100.20);
   ScpBar p2b = MkBar(D'2026.01.05 10:03', 100.15, 101.40, 100.05, 101.30);
   Ac(ScpP2(p2a, p2b, +1, 100.00, 100.40, true),
      "AC16c", "P2 mua nhấn chìm và giữ phía trên vùng", "");
   // P4: đóng vượt mép + thân >= 0,8 ATR + đóng trong 1/4 phía phá.
   ScpBar p4 = MkBar(D'2026.01.05 10:04', 101.00, 101.95, 100.95, 101.90);
   Ac(ScpP4(p4, +1, 101.50, 1.00, 0.10), "AC16d", "P4 tăng đủ thân và vị trí đóng", "");
   ScpBar weak = MkBar(D'2026.01.05 10:05', 101.00, 101.80, 100.95, 101.75);
   Ac(!ScpP4(weak, +1, 101.50, 1.00, 0.10), "AC16e", "nến đóng vượt mép nhưng thân yếu không phải P4", "");
   Ac(ScpB0(weak, +1, 101.50, 0.10), "AC16f", "B0 vẫn ghi nhận dù chưa đủ P4 (mở cửa S06)", "");
   // P1 bán đối xứng.
   ScpBar sell = MkBar(D'2026.01.05 10:06', 101.90, 102.40, 101.65, 101.70);
   Ac(ScpP1(sell, -1, 101.80, 102.20, 1.00, true),
      "AC16g", "P1 bán đối xứng tại kháng cự", "");
   // P3: đóng vượt đỉnh nhỏ đã khóa của nhịp đi vào vùng.
   ScpBar p3 = MkBar(D'2026.01.05 10:07', 100.50, 100.97, 100.45, 100.95);
   Ac(ScpP3(p3, +1, 100.80, 0.10, true), "AC16h", "P3 mua khi đóng vượt đỉnh nhỏ thêm đệm", "");
   Ac(!ScpP3(p3, +1, 101.50, 0.10, true), "AC16i", "chưa vượt đỉnh nhỏ thì không phải P3", "");
   Ac(!ScpP3(p3, +1, 100.80, 0.10, false), "AC16j", "P3 cần đúng vị trí đã chạm vùng", "");
  }

// ------------------------------------------------------------------ nhánh S01/S02

void BuildUpZigzag(ScpSeries &s, datetime &t, double step = 1.0)
  {
   PushSeg(s, t, 100.0, 3);
   PushSeg(s, t, 101.0, 3);
   PushSeg(s, t, 100.5, 3);
   PushSeg(s, t, 102.0, 3);
   PushSeg(s, t, 101.5, 3);
  }

void BuildDownZigzag(ScpSeries &s, datetime &t)
  {
   PushSeg(s, t, 110.0, 3);
   PushSeg(s, t, 109.0, 3);
   PushSeg(s, t, 109.5, 3);
   PushSeg(s, t, 108.0, 3);
   PushSeg(s, t, 108.5, 3);
  }

void TestScenarios()
  {
   SFR.Init();
   SZN.Init();
   SEP.Init();

   datetime t1 = D'2026.01.05 00:00';
   ScpSeries *m1 = SFR.Get(SCP_TF_M1);
   BuildUpZigzag(*m1, t1);
   // Vùng hỗ trợ M1 dưới giá.
   ScpBar zb = ZoneBar(t1, 100.6, 100.7, 100.0, 100.4);
   long zid = SZN.AddFromPivot(SCP_TF_M1, zb, false, t1 + 60, 1.0, 0.01);
   // Cản kháng cự M15 phía trên làm mục tiêu.
   ScpBar zbR = MkBar(t1, 105.6, 105.7, 105.0, 105.3, 900);
   SZN.AddFromPivot(SCP_TF_M5, zbR, true, t1 + 900, 1.0, 0.01);
   ScpZone z;
   SZN.Find(zid, z);
   double eps_g = 0.10;
   SEP.Watch(z, 101.2, eps_g, t1 + 600, SCP_TF_M1, 1.0, 0, 101.2, 100.3);
   long eid = SEP.Watch(z, 100.2, eps_g, t1 + 700, SCP_TF_M1, 1.0, 0, 101.2, 100.3);
   // Nến phản ứng P1 (V01) là nến đóng cuối của M1.
   m1.PushBar(MkBar(t1 + 900, 100.50, 100.60, 99.60, 100.55));
   ScpQuote q;
   q.bid = 100.55;
   q.ask = 100.75;
   q.time = t1 + 960;
   ScpScenarioEngine eng;
   ScpProposal p;
   string conflict = "";
   bool got = eng.Run(SFR, SZN, SEP, q, p, conflict);
   Ac(got, "AC01a", "S01/S02 phát đề nghị khi có vùng + phản ứng mới tại hỗ trợ",
      "got=" + (got ? "true" : "false") + " conflict=" + conflict);
   if(got)
     {
      Ac(p.direction == +1 && p.zone_id == zid && p.episode_id == eid,
         "AC01b", "đề nghị đúng chiều mua, đúng vùng và episode", "");
      Ac(p.scenario == SCP_SC_S01, "AC01c", "D1 chưa rõ thì nhãn là S01 (thuận nhịp M1)",
         "scenario=" + ScpScenarioName(p.scenario));
      Ac(p.context == SCP_CTX_UNDEFINED, "AC01d", "hướng lớn chưa rõ thì bối cảnh ghi UNDEFINED", "");
     }

   // AC02: D1 giảm rõ, M1 bật tăng tại hỗ trợ → phải xét S02, không bị cổng H1 loại.
   datetime td = D'2026.01.05 00:00';
   BuildDownZigzag(*SFR.Get(SCP_TF_D1), td);
   long eid2 = 0;
   SZN2.Init();
   SEP2.Init();
   long zid2 = SZN2.AddFromPivot(SCP_TF_M1, zb, false, t1 + 60, 1.0, 0.01);
   SZN2.AddFromPivot(SCP_TF_M5, zbR, true, t1 + 900, 1.0, 0.01);
   ScpZone z2;
   SZN2.Find(zid2, z2);
   SEP2.Watch(z2, 101.2, eps_g, t1 + 600, SCP_TF_M1, 1.0, 0, 101.2, 100.3);
   eid2 = SEP2.Watch(z2, 100.2, eps_g, t1 + 700, SCP_TF_M1, 1.0, 0, 101.2, 100.3);
   ScpProposal p2;
   conflict = "";
   eng.Init(); // bối cảnh kiểm độc lập, không phải gọi lặp cùng một nến
   bool got2 = eng.Run(SFR, SZN2, SEP2, q, p2, conflict);
   Ac(got2 && p2.scenario == SCP_SC_S02 && p2.context == SCP_CTX_COUNTER_LARGE,
      "AC02a", "D1 giảm vẫn xét được nhịp mua ngược hướng lớn (S02/COUNTER_LARGE)",
      "got=" + (got2 ? "true" : "false") + " sc=" + ScpScenarioName(p2.scenario) + " ctx=" + ScpContextName(p2.context));
  }

// ------------------------------------------------------------------ kế hoạch và tiền (V08)

void TestPlanMoney()
  {
   ScpFakeMoney money;
   ScpPlanBuilder pb;
   pb.Init(GetPointer(money), 0.25, 1.2);
   ScpProposal p;
   p.scenario = SCP_SC_S01;
   p.zone_id = 1;
   p.episode_id = 1;
   p.entry_tf = SCP_TF_M1;
   p.management_tf = SCP_TF_M1;
   p.direction = +1;
   p.thesis = SCP_THESIS_LOCAL_REACTION;
   p.context = SCP_CTX_UNDEFINED;
   p.reaction = SCP_RE_P1;
   p.reaction_known_at = D'2026.01.05 10:00';
   p.invalidation = 99.60;
   p.target_zone_id = 2;
   p.target_edge = 105.00;
   p.atr_ref = 1.00;
   p.atr_m1 = 1.00;
   p.reaction_bid = 100.55;
   p.confirmation_edge = 100.40;
   p.reaction_mono = 0;
   p.why = "test";
   ScpQuote q;
   q.bid = 100.55;
   q.ask = 100.75;
   q.time = D'2026.01.05 10:00';
   ScpSymbolSpec sp;
   sp.symbol = "XAUUSDm";
   sp.tick_size = 0.01;
   sp.point = 0.01;
   sp.digits = 2;
   sp.volume_min = 0.01;
   sp.volume_max = 100.0;
   sp.volume_step = 0.01;
   sp.stops_level_points = 0;
   sp.spread_now = 0.20;
   sp.commission_per_lot = 0.0;
   ScpPlan plan;
   ENUM_SCP_SKIP skip;
   string why = "";
   bool ok = pb.Build(p, q, sp, plan, skip, why);
   Ac(ok, "AC25a", "kế hoạch V08 dựng được", "why=" + why + " skip=" + ScpSkipName(skip));
   if(ok)
     {
      Ac(MathAbs(plan.sl - 99.40) < 1e-9, "AC25b", "dừng lỗ mua = mốc sai − đệm (99,40)",
         "sl=" + DoubleToString(plan.sl, 2));
      Ac(MathAbs(plan.tp - 104.80) < 1e-9, "AC25c", "chốt lời trước cản (104,80)",
         "tp=" + DoubleToString(plan.tp, 2));
      Ac(MathAbs(plan.volume - 0.10) < 1e-9, "AC25d", "khối lượng làm tròn xuống theo ngân sách 0,25%",
         "vol=" + DoubleToString(plan.volume, 3));
      Ac(MathAbs(plan.expected_risk - 23.50) < 0.01, "AC25e", "rủi ro đúng 23,50 với 0,10 lot",
         "risk=" + DoubleToString(plan.expected_risk, 2));
      Ac(MathAbs(plan.expected_reward - 30.50) < 0.01, "AC25f", "lời ròng đúng 30,50 với 0,10 lot",
         "reward=" + DoubleToString(plan.expected_reward, 2));
      Ac(MathAbs(plan.net_reward_risk - 1.298) < 0.01, "AC25g", "tỷ lệ ròng ~1,298",
         "rr=" + DoubleToString(plan.net_reward_risk, 3));
      Ac(plan.entry_price_limit <= 100.85 && plan.entry_price_limit >= 100.75,
         "AC10a", "giới hạn giá vào suy từ tỷ lệ và khoảng đuổi xa",
         "limit=" + DoubleToString(plan.entry_price_limit, 3));
      Ac(plan.send_deadline == q.time + 2, "AC40a", "hạn gửi 2 giây kể từ lúc xác nhận", "");
      Ac(plan.hold_deadline==0 && plan.no_progress_deadline==0,"PX15","kế hoạch không đặt hạn ép đóng theo phút");
     }
   ScpPlanBuilder scaled; scaled.Init(GetPointer(money),0.25,1.2,3,2.5);
   ScpPlan scaled_plan;
   bool fallback=scaled.Build(p,q,sp,scaled_plan,skip,why);
   Ac(fallback && scaled_plan.partial_volume==0 && MathAbs(scaled_plan.expected_reward-30.50)<0.01 &&
      scaled_plan.sl==plan.sl && scaled_plan.tp==plan.tp && scaled_plan.volume==plan.volume,
      "PX16","chốt phần không đạt thì giữ toàn bộ, không đổi điểm vào dừng chốt hoặc khối lượng");
   scaled.Init(GetPointer(money),0.25,1.0,3,2.5); // chỉ hạ ngưỡng trong ca công thức để đọc kết quả
   bool scaled_ok=scaled.Build(p,q,sp,scaled_plan,skip,why);
   Ac(scaled_ok && MathAbs(scaled_plan.expected_reward-25.25)<0.01 &&
      MathAbs(scaled_plan.partial_volume-0.05)<1e-8,"PX17","lời dự kiến tính đúng cả hai phần sau chi phí");
   // V07: ngân sách quá nhỏ thì phải bỏ, không làm tròn lên vượt rủi ro.
   ScpQuote stale=q; stale.time=q.time+3;
   ScpPlan staleplan;
   Ac(!pb.Build(p,stale,sp,staleplan,skip,why) && skip==SCP_SKIP_STALE_SIGNAL,"REG08","không cấp hạn mới cho xác nhận cũ");
   ScpQuote chase=q; chase.bid+=0.3; chase.ask+=0.3;
   Ac(!pb.Build(p,chase,sp,staleplan,skip,why) && skip==SCP_SKIP_TOO_FAR,"REG09","giá đuổi đo từ Bid xác nhận");
   ScpFakeMoney small;
   small.equity = 10.0;   // 0,25% = 0,025 → dưới mức 0,01 lot
   ScpPlanBuilder pb2;
   pb2.Init(GetPointer(small), 0.25, 1.2);
   ScpPlan plan2;
   bool ok2 = pb2.Build(p, q, sp, plan2, skip, why);
   Ac(!ok2 && skip == SCP_SKIP_VOLUME_MIN, "AC25h", "ngân sách dưới lot nhỏ nhất thì bỏ kế hoạch",
      "ok=" + (ok2 ? "true" : "false") + " skip=" + ScpSkipName(skip) + " why=" + why);
  }

// ------------------------------------------------------------------ nhánh S01 bán đối xứng

void TestScenarioSell()
  {
   SFR.Init();
   SZN.Init();
   SEP.Init();
   datetime t = D'2026.01.06 00:00';
   ScpSeries *m1 = SFR.Get(SCP_TF_M1);
   BuildDownZigzag(*m1, t);
   // Kháng cự M1 phía trên: [max(O,C)=100.6, H=101.0].
   ScpBar zb = MkBar(t, 100.6, 101.0, 100.2, 100.3);
   long zid = SZN.AddFromPivot(SCP_TF_M1, zb, true, t + 60, 1.0, 0.01);
   // Hỗ trợ M15 phía dưới làm mục tiêu.
   ScpBar zbS = MkBar(t, 95.6, 95.7, 95.0, 95.4, 900);
   SZN.AddFromPivot(SCP_TF_M5, zbS, false, t + 900, 1.0, 0.01);
   ScpZone z;
   SZN.Find(zid, z);
   double eps_g = 0.10;
   // Tiếp cận kháng cự từ phía dưới mới hợp lệ.
   SEP.Watch(z, 100.0, eps_g, t + 600, SCP_TF_M1, 1.0, 0, 101.2, 100.3);
   long eid = SEP.Watch(z, 100.8, eps_g, t + 700, SCP_TF_M1, 1.0, 0, 101.2, 100.3);
   Ac(eid > 0, "AC02b", "tiếp cận kháng cự từ dưới mở episode bán", "eid=" + IntegerToString((int)eid));
   // Nến P1 bán: râu trên dài, đóng dưới đáy vùng.
   m1.PushBar(MkBar(t + 900, 100.80, 101.40, 100.45, 100.50));
   ScpQuote q;
   q.bid = 100.50;
   q.ask = 100.70;
   q.time = t + 960;
   ScpScenarioEngine eng;
   ScpProposal p;
   string conflict = "";
   bool got = eng.Run(SFR, SZN, SEP, q, p, conflict);
   Ac(got && p.direction == -1 && p.scenario == SCP_SC_S01,
      "AC02c", "S01 bán đối xứng khi nhịp M1 giảm và có phản ứng mới",
      "got=" + (got ? "true" : "false") + " sc=" + ScpScenarioName(p.scenario) + " dir=" + IntegerToString(p.direction));
   if(got)
     {
      int idx = -1;
      SEP.ByIdWritable(p.episode_id, idx);
      SEP.ConsumeReaction(idx, p.reaction_known_at, p.reaction);
      ScpProposal p2;
      string c2 = "";
      bool again = eng.Run(SFR, SZN, SEP, q, p2, c2);
      Ac(!again, "AC34a", "sự kiện xác nhận chỉ dùng một lần, không phát lại cùng nến", "");
     }
  }

// ------------------------------------------------------------------ kiểm nến sai thứ tự

void TestBarRejects()
  {
   ScpSeries s;
   s.Init(SCP_TF_M1);
   datetime t = D'2026.01.06 00:00';
   bool ok1 = s.PushBar(MkBar(t, 100.0, 100.5, 99.5, 100.2));
   bool dup = s.PushBar(MkBar(t, 100.0, 100.5, 99.5, 100.2));
   bool old = s.PushBar(MkBar(t - 60, 100.0, 100.5, 99.5, 100.2));
   bool bad = s.PushBar(MkBar(t + 120, 100.0, 99.0, 99.5, 100.2));
   Ac(ok1 && !dup && !old && !bad && s.Count() == 1,
      "AC28a", "nến trùng, ngược thời gian hoặc sai OHLC bị từ chối",
      "count=" + IntegerToString(s.Count()));
  }

// ------------------------------------------------------------------ nhánh phá S05/S06/S07

// Dựng bối cảnh chung: M1 tăng, kháng cự [100.6;101.0], episode tiếp cận từ dưới,
// cản mục tiêu M15 phía trên ở 105.
void BreakFixture(ScpFrames &frIn, ScpZoneMap &znIn, ScpEpisodeMap &epIn, datetime &t, long &zid, long &eid)
  {
   ScpSeries *m1 = frIn.Get(SCP_TF_M1);
   BuildUpZigzag(*m1, t);
   ScpBar zb = MkBar(t, 100.6, 101.0, 100.2, 100.3);
   zid = znIn.AddFromPivot(SCP_TF_M1, zb, true, t + 60, 0.5, 0.01);
   ScpBar zbT = MkBar(t, 105.6, 105.7, 105.0, 105.4, 900);
   znIn.AddFromPivot(SCP_TF_M5, zbT, true, t + 900, 0.5, 0.01);
   ScpZone z;
   znIn.Find(zid, z);
   double eps_g = 0.05;
   epIn.Watch(z, 100.2, eps_g, t + 600, SCP_TF_M1, 0.5, 0, 0, 0);
   eid = epIn.Watch(z, 100.8, eps_g, t + 700, SCP_TF_M1, 0.5, 0, 0, 0);
  }

void TestBreakBranches()
  {
   ScpScenarioEngine eng;
   eng.Init();
   // ---- S05: P4 phá vừa xác nhận, giá còn phía mới.
   {
    SFR.ResetAll();
    SZN.Init();
    SEP.Init();
    datetime t = D'2026.01.07 00:00';
    long zid = 0, eid = 0;
    BreakFixture(SFR, SZN, SEP, t, zid, eid);
    ScpSeries *m1 = SFR.Get(SCP_TF_M1);
    ScpBar p4 = MkBar(t + 900, 101.00, 101.95, 100.95, 101.90);
    m1.PushBar(p4);
    SEP.OnBarClosed((int)SCP_TF_M1, p4, SZN, 0.05, t + 960);
    ScpQuote q; q.bid = 101.90; q.ask = 102.10; q.time = t + 960;
    ScpProposal p; string conflict = "";
    bool got = eng.Run(SFR, SZN, SEP, q, p, conflict);
    Ac(got && p.scenario == SCP_SC_S05 && p.direction == +1 && p.thesis == SCP_THESIS_BREAK_HOLD,
       "AC09a", "S05 đi theo P4 vừa xác nhận, không cần chờ hồi",
       "got=" + (got ? "true" : "false") + " sc=" + ScpScenarioName(p.scenario));
    Ac(got && MathAbs(p.invalidation - 100.95) < 0.06, "AC09b", "mốc sai S05 ngoài đáy nến phá và mép vùng",
       "inval=" + DoubleToString(p.invalidation, 3));
    if(got)
      {
       SEP.ConsumeBreak(p.break_id);
       ScpProposal p2; string c2 = "";
       bool again = eng.Run(SFR, SZN, SEP, q, p2, c2);
       Ac(!again, "AC09c", "sự kiện phá chỉ dùng một lần", "");
      }
   }
   // ---- S06: phá rồi quay lại giữ được phía mới.
   {
    eng.Init();
    SFR.ResetAll();
    SZN.Init();
    SEP.Init();
    datetime t = D'2026.01.07 00:00';
    long zid = 0, eid = 0;
    BreakFixture(SFR, SZN, SEP, t, zid, eid);
    ScpSeries *m1 = SFR.Get(SCP_TF_M1);
    ScpBar brk = MkBar(t + 900, 101.00, 101.95, 100.70, 101.90);
    m1.PushBar(brk);
    SEP.OnBarClosed((int)SCP_TF_M1, brk, SZN, 0.05, t + 960);
    ScpEpisode e0;
    SEP.ById(eid, e0);
    Ac(e0.state == SCP_EP_BREAK_CONFIRMED, "AC06x", "episode chuyển BREAK_CONFIRMED sau nến phá đóng vượt mép",
       "state=" + IntegerToString((int)e0.state) + " breaks=" + IntegerToString(SEP.BreakCount()));
    ScpBar ret = MkBar(t + 960, 101.40, 101.50, 100.90, 101.45);
    m1.PushBar(ret);
    SEP.OnBarClosed((int)SCP_TF_M1, ret, SZN, 0.05, t + 1020);
    ScpQuote q; q.bid = 101.45; q.ask = 101.65; q.time = t + 1020;
    ScpProposal p; string conflict = "";
    bool got = eng.Run(SFR, SZN, SEP, q, p, conflict);
    Ac(got && p.scenario == SCP_SC_S06 && p.direction == +1,
       "AC06a", "S06 kiểm tra lại giữ được mép thì vào theo chiều mới",
       "got=" + (got ? "true" : "false") + " sc=" + ScpScenarioName(p.scenario));
    Ac(got && p.reaction == SCP_RE_P5, "AC06b", "S06 ghi nhận P5 làm phản ứng", ScpReactionWhy(p.reaction));
   }
   // ---- S07: xuyên lên rồi lấy lại phía cũ.
   {
    eng.Init();
    SFR.ResetAll();
    SZN.Init();
    SEP.Init();
    datetime t = D'2026.01.07 00:00';
    long zid = 0, eid = 0;
    BreakFixture(SFR, SZN, SEP, t, zid, eid);
    ScpBar zbS = MkBar(t, 95.6, 95.7, 95.0, 95.4, 900);
    SZN.AddFromPivot(SCP_TF_M5, zbS, false, t + 900, 0.5, 0.01);
    ScpSeries *m1 = SFR.Get(SCP_TF_M1);
    ScpBar weak = MkBar(t + 900, 100.90, 101.20, 100.85, 101.15);
    m1.PushBar(weak);
    SEP.OnBarClosed((int)SCP_TF_M1, weak, SZN, 0.05, t + 960);
    ScpBar back = MkBar(t + 960, 101.05, 101.60, 100.85, 100.90);
    m1.PushBar(back);
    SEP.OnBarClosed((int)SCP_TF_M1, back, SZN, 0.05, t + 1020);
    ScpQuote q; q.bid = 100.90; q.ask = 101.10; q.time = t + 1020;
    ScpProposal p; string conflict = "";
    bool got = eng.Run(SFR, SZN, SEP, q, p, conflict);
    Ac(got && p.scenario == SCP_SC_S07 && p.direction == -1,
       "AC05a", "S07 xuyên lên rồi lấy lại phía cũ trong 2 nến",
       "got=" + (got ? "true" : "false") + " sc=" + ScpScenarioName(p.scenario));
    Ac(got && p.invalidation >= 101.60 - 1e-9, "AC05b", "mốc sai S07 ngoài cực trị cú xuyên",
       "inval=" + DoubleToString(p.invalidation, 3));
   }
  }

// ------------------------------------------------------------------ S04 đi ngang

void TestRangeBranch()
  {
   ScpScenarioEngine eng;
   eng.Init();
   SFR.ResetAll();
   SZN.Init();
   SEP.Init();
   datetime t = D'2026.01.08 00:00';
   ScpSeries *m1 = SFR.Get(SCP_TF_M1);
   // Dao động 100.0 ↔ 101.0, mỗi biên ba lần để có >=2 pivot độc lập.
   ScpBar zbT = MkBar(t, 105.6, 105.7, 105.0, 105.4, 900);
   SZN.AddFromPivot(SCP_TF_M5, zbT, true, t + 900, 1.0, 0.01);
   PushSeg(*m1, t, 101.0, 3);
   PushSeg(*m1, t, 100.0, 3);
   PushSeg(*m1, t, 101.0, 3);
   PushSeg(*m1, t, 100.0, 3);
   PushSeg(*m1, t, 101.0, 3);
   PushSeg(*m1, t, 100.0, 3);
   PushSeg(*m1, t, 101.0, 3);
   // Nến phản ứng tại biên dưới: râu dưới dài, đóng lên trên mép.
   ScpBar re = MkBar(t, 100.25, 100.35, 99.75, 100.30);
   m1.PushBar(re);
   ScpQuote q; q.bid = 100.05; q.ask = 100.25; q.time = t + 60;
   ScpProposal p; string conflict = "";
   bool got = eng.Run(SFR, SZN, SEP, q, p, conflict);
   Ac(m1.PivotCount() >= 6, "AC12x", "đủ pivot hai biên để nhận diện đi ngang",
      "pivots=" + IntegerToString(m1.PivotCount()) + " bars=" + IntegerToString(m1.Count()) +
      " atr=" + DoubleToString(m1.Atr(), 3));
   Ac(got && p.scenario == SCP_SC_S04 && p.direction == +1,
      "AC12a", "S04 vào tại biên dưới khi có phản ứng",
      "got=" + (got ? "true" : "false") + " sc=" + ScpScenarioName(p.scenario) +
      " pivots=" + IntegerToString(m1.PivotCount()));
   Ac(got && p.invalidation < 99.75, "AC12b", "mốc sai S04 ngoài biên và cực trị phản ứng",
      "inval=" + DoubleToString(p.invalidation, 3));
   // Giữa vùng đi ngang thì không vào.
   ScpQuote mid; mid.bid = 100.50; mid.ask = 100.70; mid.time = t + 60;
   ScpProposal p2; string c2 = "";
   bool got2 = eng.Run(SFR, SZN, SEP, mid, p2, c2);
   Ac(!got2 || p2.scenario != SCP_SC_S04, "AC12c", "giữa phạm vi không phát S04", "");
  }

// ------------------------------------------------------------------ S08 EMA

void TestEmaBranch()
  {
   ScpScenarioEngine eng;
   eng.Init();
   SFR.ResetAll();
   SZN.Init();
   SEP.Init();
   datetime t = D'2026.01.09 00:00';
   ScpSeries *m5 = SFR.Get(SCP_TF_M5);
   for(int i = 0; i < 30; i++)
      m5.PushBar(MkBar(t + (datetime)(i * 300), 100.0, 100.5, 99.5, 100.0, 300));
   ScpBar zbT = MkBar(t, 105.6, 105.7, 105.0, 105.4, 900);
   SZN.AddFromPivot(SCP_TF_M5, zbT, true, t + 900, 1.0, 0.01);
   double ema = m5.Ema(20, m5.Count()-1);
   ScpSeries *m1 = SFR.Get(SCP_TF_M1);
   for(int i=0;i<150;i++) m1.PushBar(MkBar(t+i*60,100,100.5,99.5,100));
   double frozen_atr = m1.Atr();
   ScpQuote q; ZeroMemory(q); q.bid=100.3; q.ask=100.5; q.time=t+9000;
   ScpProposal p; string conflict="";
   eng.Run(SFR,SZN,SEP,q,p,conflict); // tiếp cận từ trên
   q.bid=100; q.ask=100.2; q.time=t+9001;
   eng.Run(SFR,SZN,SEP,q,p,conflict); // tick chạm EMA nguồn M5, theo dõi trên M1
   m1.PushBar(MkBar(t+9000,100.2,100.6,99.4,100.5));
   q.bid=100.5; q.ask=100.7; q.time=t+9060;
   bool got=eng.Run(SFR,SZN,SEP,q,p,conflict);
   Ac(got && p.scenario==SCP_SC_S08 && p.entry_tf==SCP_TF_M1 && p.direction==1,
      "AC13a","EMA khung lớn được xác nhận bằng M1","got="+(string)got);
   Ac(got && MathAbs(p.atr_ref-frozen_atr)<1e-9,"AC14a","ATR EMA khóa lúc chạm, không lấy ATR sau phản ứng");
   if(got) eng.Consume(p,SEP,SZN);
   Ac(!eng.Run(SFR,SZN,SEP,q,p,conflict),"REG05","EMA không phát lại cùng xác nhận");
}
// ------------------------------------------------------------------ S03 hồi nông

void TestImpulseBranch()
  {
   ScpScenarioEngine eng;
   eng.Init();
   SFR.ResetAll();
   SZN.Init();
   SEP.Init();
   datetime t = D'2026.01.10 00:00';
   long zid = 0, eid = 0;
   BreakFixture(SFR, SZN, SEP, t, zid, eid);
   ScpSeries *m1 = SFR.Get(SCP_TF_M1);
   // Nhịp đẩy kéo dài để vùng nhỏ nằm trong nửa sau đoạn đẩy.
   for(int i = 0; i < 6; i++)
      m1.PushBar(MkBar(t + 780 + (datetime)(i * 60), 101.2 + 0.1 * i, 101.5 + 0.1 * i, 101.1 + 0.1 * i, 101.4 + 0.1 * i));
   ScpBar p4 = MkBar(t + 1500, 101.80, 102.80, 101.75, 102.75);
   m1.PushBar(p4);
   SEP.OnBarClosed((int)SCP_TF_M1, p4, SZN, 0.05, t + 1560);
   // Vùng nhỏ FVG trong đoạn đẩy, đã biết trước lúc phá.
   SZN.AddFvg(SCP_TF_M1, +1, 102.30, 102.60, t + 1200, t + 1260, 0.5, 0.01, true);
   // Nhịp hồi nông chạm vùng nhỏ và có P1 mua.
   ScpBar pull = MkBar(t + 1560, 102.45, 102.65, 102.20, 102.55);
   m1.PushBar(pull);
   SEP.OnBarClosed((int)SCP_TF_M1, pull, SZN, 0.05, t + 1620);
   ScpQuote q; q.bid = 102.55; q.ask = 102.75; q.time = t + 1620;
   ScpProposal p; string conflict = "";
   bool got = eng.Run(SFR, SZN, SEP, q, p, conflict);
   Ac(got && p.scenario == SCP_SC_S03 && p.direction == +1,
      "AC11a", "S03 hồi nông về vùng nhỏ trong đoạn đẩy thì được xét",
      "got=" + (got ? "true" : "false") + " sc=" + ScpScenarioName(p.scenario));
   Ac(got && p.invalidation <= 102.20 + 1e-9, "AC11b", "mốc sai S03 ngoài đáy nhịp hồi nông",
      "inval=" + DoubleToString(p.invalidation, 3));
  }


void TestReviewRegressions()
  {
   SFR.Init(); SFR.ResetAll(); SZN.Init(); SEP.Init();
   datetime t=D'2026.01.12 00:00';
   ScpBar src=MkBar(t,101,102,100,101);
   long id=SZN.AddFromPivot(SCP_TF_H1,src,false,t+60,1,0.01);
   ScpZone z; SZN.Find(id,z);
   SEP.Watch(z,102,0.1,t+120,SCP_TF_M1,1,0,103,99);
   long eid=SEP.Watch(z,100.5,0.1,t+121,SCP_TF_M1,1,0,103,99);
   ScpBar bounce=MkBar(t+120,101.4,101.6,99.6,101.5);
   SEP.OnBarClosed(SCP_TF_M1,bounce,SZN,0.1,bounce.known_at);
   ScpEpisode ep; SEP.ById(eid,ep);
   Ac(ep.state==SCP_EP_WAIT_REACTION,"REG01","bật khỏi hỗ trợ không phải phá hỗ trợ");
   Ac(ep.ext_low<=99.6,"REG02","cực trị gồm râu phản ứng");
   Ac(ep.entry_tf==SCP_TF_M1 && z.source_tf==SCP_TF_H1,"REG06","vùng H1 theo dõi M1");
   long refid=SZN.AddMsnr(SCP_TF_M1,90,SCP_ROLE_SUPPORT,t,t+60);
   SZN.RegisterTouch(refid,t+200); SZN.RegisterTouch(refid,t+400);
   ScpZone refz; SZN.Find(refid,refz);
   Ac(refz.level==SCP_LEVEL_REFERENCE,"REG03","hai chạm chưa phải hai phản ứng");
   Ac(ScpCanStart(SCP_EX_CLOSED) && ScpCanStart(SCP_EX_REJECTED) && !ScpCanStart(SCP_EX_SENT_UNKNOWN),
      "REG07","kết thúc được gửi mới; chưa rõ phải khóa");
   ScpSeries s; s.Init(SCP_TF_M1);
   ulong began=GetMicrosecondCount();
   for(int i=0;i<5000;i++)
     {
      double c=100+3*MathSin(i*0.9);
      s.PushBar(MkBar(t+i*60,c,c+0.2,c-0.2,c));
     }
   Print("[PERF] 5000 nến: ",GetMicrosecondCount()-began," us");
   Ac(s.LastPivotKnownAt(true)>t+4900*60,"REG04","chạy lâu vẫn nhận đỉnh mới");
  }

void TestFalseBreakAndValidity()
  {
   SFR.ResetAll(); SZN.Init(); SEP.Init();
   ScpScenarioEngine eng;
   datetime t=D'2026.01.14 00:00'; long zid,eid;
   BreakFixture(SFR,SZN,SEP,t,zid,eid);
   ScpBar demand=MkBar(t,95.6,95.7,95,95.4,900);
   SZN.AddFromPivot(SCP_TF_M5,demand,false,t+900,0.5,0.01);
   ScpBar wick=MkBar(t+900,100.9,101.8,100.6,100.65);
   SFR.Get(SCP_TF_M1).PushBar(wick);
   SEP.OnBarClosed(SCP_TF_M1,wick,SZN,0.05,wick.known_at);
   ScpQuote q; ZeroMemory(q); q.bid=100.65; q.ask=100.85; q.time=wick.known_at;
   ScpProposal p; string conflict="";
   bool got=eng.Run(SFR,SZN,SEP,q,p,conflict);
   Ac(got && p.scenario==SCP_SC_S07,"REG10","râu xuyên rồi rút lại không cần đóng phá trước");
   ScpZone original; SZN.Find(zid,original);
   long same=SZN.AddFromPivot(SCP_TF_M5,demand,false,t+900,0.5,0.01);
   ScpZone samezone;
   Ac(SZN.Find(same,samezone),"REG11","thêm vùng trùng trả lại mã vùng tồn tại");
   ScpSeries delayed; delayed.Init(SCP_TF_M1);
   for(int i=0;i<5;i++)
     {
      double h=i==2?105:101;
      ScpBar bb=MkBar(t+i*60,100,h,99,100);
      bb.known_at=t+1000+i;
      delayed.PushBar(bb);
     }
   Ac(delayed.LastPivotKnownAt(true)==t+1004,"REG12","đỉnh nhận muộn không ghi lùi giờ biết");
   SZN.RegisterReaction(same,1001); SZN.RegisterReaction(same,1001);
   ScpZone z;
   long weak=SZN.AddMsnr(SCP_TF_M1,92,SCP_ROLE_SUPPORT,t,t+60);
   SZN.RegisterReaction(weak,1); SZN.RegisterReaction(weak,1); SZN.Find(weak,z);
   Ac(z.level==SCP_LEVEL_REFERENCE,"REG13","không đếm lặp cùng phản ứng");
   SZN.RegisterReaction(weak,2); SZN.Find(weak,z);
   Ac(z.level==SCP_LEVEL_REACTION,"REG14","hai phản ứng mới nâng vùng");
  }

void TestIndicatorsLongRun()
  {
   ScpSeries series; series.Init(SCP_TF_M5);
   double ema=0,sum=0,atr=0,prev=0,max_error=0;
   datetime t=D'2026.01.01';
   ulong began=GetMicrosecondCount();
   for(int i=0;i<4000;i++)
     {
      double c=100+MathSin(i*0.03)*5+i*0.001;
      ScpBar b=MkBar(t+i*300,c,c+0.5,c-0.5,c,300);
      double tr=i==0 ? 1 : MathMax(1,MathMax(MathAbs(b.h-prev),MathAbs(b.l-prev)));
      atr=i==0 ? tr : (atr*13+tr)/14;
      sum+=c;
      if(i==199) ema=sum/200;
      else if(i>199) ema=c*(2.0/201)+ema*(1-2.0/201);
      series.PushBar(b);
      if(i>=199) max_error=MathMax(max_error,MathAbs(series.Ema(200,series.Count()-1)-ema));
      prev=c;
     }
   Print("[PERF] 4000 M5 EMA: ",GetMicrosecondCount()-began," us; sai số ",DoubleToString(max_error,12));
   Ac(max_error<1e-9,"REG15","EMA không bị tính lại từ đầu khi vòng nến đầy",DoubleToString(max_error,12));
   Ac(MathAbs(series.Atr()-atr)<1e-9,"REG16","ATR liên tục khi vòng nến đầy");
  }

void TestIndependentCandidates()
  {
   SFR.ResetAll(); SZN.Init(); SEP.Init(); ScpScenarioEngine eng;
   datetime t=D'2026.01.20 00:00';
   ScpSeries *s=SFR.Get(SCP_TF_M1); BuildUpZigzag(*s,t);
   ScpBar demand=MkBar(t,100.6,100.7,100,100.4);
   ScpBar target=MkBar(t,105.6,105.7,105,105.3,900);
   SZN.AddFromPivot(SCP_TF_M5,target,true,t+900,1,0.01);
   for(int k=0;k<2;k++)
     {
      long id=SZN.AddFromPivot(k==0?SCP_TF_M1:SCP_TF_H1,demand,false,t+60,1,0.01);
      ScpZone z; SZN.Find(id,z);
      SEP.Watch(z,101.2,0.1,t+600,SCP_TF_M1,1,0,101.2,100.3);
      SEP.Watch(z,100.2,0.1,t+700,SCP_TF_M1,1,0,101.2,100.3);
     }
   ScpBar bounce=MkBar(t+900,100.5,100.6,99.6,100.55); s.PushBar(bounce);
   SEP.OnBarClosed(SCP_TF_M1,bounce,SZN,0.1,bounce.known_at);
   ScpQuote q; ZeroMemory(q); q.bid=100.55;q.ask=100.75;q.time=bounce.known_at;
   ScpProposal p,next; string conflict="";
   bool first=eng.Run(SFR,SZN,SEP,q,p,conflict);
   bool second=eng.Next(next);
   Ac(first && second && p.zone_id!=next.zone_id,"REG17","đề nghị độc lập còn được xét khi đề nghị đầu không đạt");
  }

void TestPriceManagement()
  {
   double sl=0;
   Ac(ScpEntryStop(1,100,102.5,98,2.5,0.01,0.1,sl) && sl==100,"PX01","mua đủ 2,5 giá: dừng về giá vào");
   Ac(ScpEntryStop(-1,100,97.5,102,2.5,0.01,0.1,sl) && sl==100,"PX02","bán đủ 2,5 giá: dừng về giá vào");
   Ac(!ScpEntryStop(1,100,102.4,98,2.5,0.01,0.1,sl),"PX03","chưa đủ mức đi thuận không kéo sớm");
   Ac(!ScpEntryStop(1,100,103,101,2.5,0.01,0.1,sl),"PX04","không nới dừng tốt hơn về giá vào");
   Ac(!ScpEntryStop(1,100,102.5,98,2.5,0.01,3,sl),"PX05","không sửa dừng vi phạm khoảng cách sàn");
   Ac(ScpHalfVolume(0.01,0.01,0.01)==0,"PX06","0,01 lot không bị chốt hết dưới tên chốt nửa");
   Ac(MathAbs(ScpHalfVolume(0.02,0.01,0.01)-0.01)<1e-8,"PX07","0,02 chia 0,01 và 0,01");
   Ac(MathAbs(ScpHalfVolume(0.03,0.01,0.01)-0.01)<1e-8,"PX08","0,03 làm tròn phần chốt xuống 0,01");
   datetime t=D'2026.01.20';
   ScpBar prev=MkBar(t,100,100.5,99.9,100.4);
   ScpBar weak=MkBar(t+60,100.4,100.5,100.2,100.3);
   ScpBar strong=MkBar(t+60,100.4,101.5,99.2,99.3);
   Ac(!ScpStrongCounter(prev,weak,1,100.2,100.6,1,0.1,100.1,t),"PX09","hồi nhẹ không đủ chốt sớm");
   Ac(ScpStrongCounter(prev,strong,1,100.2,100.6,1,0.1,100.1,t),"PX10","phản ứng tại cản và phá đáy bảo vệ mới đủ thoát");
   Ac(!ScpStrongCounter(prev,strong,1,100.2,100.6,1,0.1,0,t),"PX11","thiếu cấu trúc bảo vệ không bịa lý do thoát");
   ScpBar tiny_prev=MkBar(t,100.3,100.45,100.29,100.4);
   ScpBar tiny=MkBar(t+60,100.4,100.42,100.19,100.2);
   Ac(!ScpStrongCounter(tiny_prev,tiny,1,100.3,100.4,1,0.01,100.25,t),
      "PX18","nhấn chìm nhỏ dù vượt mốc gần vẫn không gọi phản ứng mạnh");
   SZN.Init();
   ScpBar h4=MkBar(t,119,120,118,119);
   SZN.AddFromPivot(SCP_TF_H4,h4,true,t+60,1,0.01);
   long id; double edge; ENUM_SCP_ROLE role; ENUM_SCP_TF tf;
   Ac(!SZN.NearestScalpTarget(100,1,0,id,edge,role,tf),"PX12","không lấy mỗi H4 xa để tạo mục tiêu scalping");
   ScpBar local=MkBar(t,124,125,123,124);
   SZN.AddFromPivot(SCP_TF_M5,local,true,t+60,1,0.01);
   Ac(SZN.NearestScalpTarget(100,1,0,id,edge,role,tf) && edge==119,"PX13","cản khung lớn gần hơn vẫn chặn đường tới mục tiêu nhỏ");
   ScpBar close=MkBar(t+60,100.05,100.1,100,100.05);
   SZN.AddFromPivot(SCP_TF_M1,close,true,t+120,1,0.01);
   Ac(SZN.NearestScalpTarget(100,1,0,id,edge,role,tf) && MathAbs(edge-100.05)<1e-8,"PX14","không bỏ cản sát để chọn đích xa làm đẹp tỷ lệ");
   Ac(SZN.NearestOpposite(100,1,0,id,edge,role,tf,0,SCP_TF_D1,t+60) && edge==119,
      "PX19","vùng vừa hình thành không được dùng giải thích phản ứng trước lúc biết");
  }

void TestReentryAfterExpired()
  {
   SZN.Init(); SEP.Init();
   datetime t=D'2026.02.01 00:00';
   ScpBar source=MkBar(t,101,102,100,101);
   long zid=SZN.AddFromPivot(SCP_TF_M1,source,false,t+60,1,0.01);
   ScpZone z; SZN.Find(zid,z);
   SEP.Watch(z,102,0.1,t+120,SCP_TF_M1,1,0,103,99);
   long first=SEP.Watch(z,100.5,0.1,t+130,SCP_TF_M1,1,0,103,99);
   SEP.Cleanup(t+900,60); // episode hết hạn; vị thế kết thúc sau đó
   datetime closed=t+920;
   SEP.Watch(z,102,0.1,t+930,SCP_TF_M1,1,closed,103,99);
   Ac(SEP.Watch(z,100.5,0.1,t+940,SCP_TF_M1,1,closed,103,99)==0,"EN01","chưa có nến rời mới sau đóng thì không vào lại");
   ScpBar leave=MkBar(t+960,102,103,101.5,102.5);
   SEP.OnBarClosed(SCP_TF_M1,leave,SZN,0.1,leave.known_at);
   SEP.Watch(z,102,0.1,t+1021,SCP_TF_M1,1,closed,103,99);
   long next=SEP.Watch(z,100.5,0.1,t+1030,SCP_TF_M1,1,closed,103,99);
   Ac(next>0 && next!=first,"EN02","episode hết hạn vẫn ghi nến rời mới và cho chạm mới sau đóng");
  }

void TestProfitProtection()
  {
   datetime t=D'2026.03.01';
   ScpBar strong=MkBar(t+60,105,105.1,102.9,103);
   ScpBar weak=MkBar(t+60,103.5,103.7,103.3,103.4);
   Ac(ScpProfitReversal(strong,1,100,103,100,5,2.5,104,1,0.1,t),"EN03","đã bảo vệ và nến giảm mạnh phá đáy sau khớp thì giữ lời");
   Ac(!ScpProfitReversal(weak,1,100,103.4,100,5,2.5,104,1,0.1,t),"EN04","hồi nhẹ không bị chốt lời máy móc");
   Ac(!ScpProfitReversal(strong,1,100,103,98,5,2.5,104,1,0.1,t),"EN05","chưa có dừng bảo vệ không dùng nhánh tránh về giá vào");
   Ac(!ScpProfitReversal(strong,1,100,99.9,100,5,2.5,104,1,0.1,t),"EN06","đã hết lời không báo chốt giữ lời");
   ScpBar sell=MkBar(t+60,95,97.1,94.9,97);
   Ac(ScpProfitReversal(sell,-1,100,97,100,5,2.5,96,1,0.1,t),"EN07","bảo vệ lời bán đối xứng");
  }

// ------------------------------------------------------------------ sửa sau review 28/09 (SCP-MTF-1.3)

void TestReviewFixes()
  {
   // RF01: D1 giảm, M1 đang hồi lên kháng cự rồi bị từ chối → S01 bán thuận hướng lớn, không bị bỏ vì M1 đang tăng.
   SFR.Init(); SZN.Init(); SEP.Init();
   datetime t = D'2026.01.07 00:00';
   ScpSeries *m1 = SFR.Get(SCP_TF_M1);
   BuildUpZigzag(*m1, t);
   datetime td = D'2026.01.07 00:00';
   BuildDownZigzag(*SFR.Get(SCP_TF_D1), td);
   long zid = SZN.AddFromPivot(SCP_TF_M1, MkBar(t, 102.6, 103.0, 102.2, 102.4), true, t + 60, 1.0, 0.01);
   SZN.AddFromPivot(SCP_TF_M5, MkBar(t, 97.6, 97.7, 97.0, 97.4, 300), false, t + 300, 1.0, 0.01);
   ScpZone z; SZN.Find(zid, z);
   SEP.Watch(z, 102.3, 0.10, t + 600, SCP_TF_M1, 1.0, 0, 101.2, 101.5);
   long eid = SEP.Watch(z, 102.8, 0.10, t + 700, SCP_TF_M1, 1.0, 0, 101.2, 101.5);
   m1.PushBar(MkBar(t + 900, 102.80, 103.40, 102.45, 102.50));
   ScpQuote q; q.bid = 102.50; q.ask = 102.70; q.time = t + 960;
   ScpScenarioEngine eng;
   ScpProposal p; string conflict = "";
   bool got = eng.Run(SFR, SZN, SEP, q, p, conflict);
   Ac(got && p.direction == -1 && p.scenario == SCP_SC_S01 && p.context == SCP_CTX_WITH_LARGE && m1.Dir() == SCP_DIR_UP,
      "RF01", "D1 giảm, M1 hồi lên kháng cự bị từ chối: xét S01 bán thuận hướng lớn",
      "got=" + (got ? "true" : "false") + " sc=" + ScpScenarioName(p.scenario) + " m1=" + IntegerToString((int)m1.Dir()) +
      " eid=" + IntegerToString((int)eid) + " conflict=" + conflict);
   if(got)
     {
      // RF02: kế hoạch bị loại không khóa cả lần chạm; nến phản ứng mới trong lần chạm vẫn được xét.
      eng.Consume(p, SEP, SZN, false);
      ScpEpisode e; SEP.ById(eid, e);
      Ac(e.state == SCP_EP_WAIT_REACTION && e.reaction_at == p.reaction_known_at, "RF02a",
         "phản ứng bị loại kế hoạch: episode vẫn chờ, nến đó không dùng lại");
      ScpProposal again; conflict = "";
      Ac(!eng.Run(SFR, SZN, SEP, q, again, conflict), "RF02b", "không phát lại cùng nến đã xét");
      m1.PushBar(MkBar(t + 960, 102.55, 103.10, 102.40, 102.45));
      ScpQuote q2 = q; q2.bid = 102.45; q2.ask = 102.65; q2.time = t + 1020;
      ScpProposal p2; conflict = "";
      bool got2 = eng.Run(SFR, SZN, SEP, q2, p2, conflict);
      Ac(got2 && p2.episode_id == eid && p2.reaction_known_at > p.reaction_known_at, "RF02c",
         "nến phản ứng mới trong cùng lần chạm được xét sau khi phản ứng trước bị loại");
      if(got2)
        {
         eng.Consume(p2, SEP, SZN, true);
         m1.PushBar(MkBar(t + 1020, 102.50, 103.05, 102.35, 102.40));
         ScpQuote q3 = q2; q3.bid = 102.40; q3.ask = 102.60; q3.time = t + 1080;
         ScpProposal p3; conflict = "";
         Ac(!eng.Run(SFR, SZN, SEP, q3, p3, conflict), "RF02d", "phản ứng đã thành kế hoạch thì khóa lần chạm như cũ");
        }
     }

   // RF03: vùng M1 chưa có phản ứng không làm cản mục tiêu khi bật lọc; có phản ứng thì vẫn là cản.
   SZN2.Init();
   datetime tz = D'2026.01.08 00:00';
   long m1z = SZN2.AddFromPivot(SCP_TF_M1, MkBar(tz, 101.0, 101.4, 100.9, 101.1), true, tz + 60, 1.0, 0.01);
   SZN2.AddFromPivot(SCP_TF_M5, MkBar(tz, 105.0, 105.5, 104.8, 105.2, 300), true, tz + 300, 1.0, 0.01);
   long id = 0; double edge = 0; ENUM_SCP_ROLE role; ENUM_SCP_TF tf;
   SZN2.SetM1TargetNeedsReaction(false);
   Ac(SZN2.NearestScalpTarget(100, 1, 0, id, edge, role, tf) && id == m1z, "RF03a", "tắt lọc: cản M1 gần nhất như cũ");
   SZN2.SetM1TargetNeedsReaction(true);
   Ac(SZN2.NearestScalpTarget(100, 1, 0, id, edge, role, tf) && MathAbs(edge - 105.2) < 1e-8, "RF03b",
      "bật lọc: bỏ đỉnh M1 chưa có phản ứng, lấy cản M5", "edge=" + DoubleToString(edge, 3));
   SZN2.RegisterReaction(m1z, 77);
   Ac(SZN2.NearestScalpTarget(100, 1, 0, id, edge, role, tf) && id == m1z, "RF03c", "vùng M1 đã có phản ứng vẫn chặn đường");
   SZN2.SetM1TargetNeedsReaction(false);

   // RF04: bảng vùng đầy phải đếm vùng bị bỏ, không im lặng.
   SZN2.Init();
   int dropped0 = SZN2.Dropped();
   long id5 = 0, idl = 0;
   for(int i = 0; i <= SCP_MAX_ZONES; i++)
     {
      long nid = SZN2.AddMsnr(SCP_TF_M1, 100 + i * 0.01, SCP_ROLE_SUPPORT, tz + i * 60, tz + i * 60 + 60);
      if(i == 5) id5 = nid;
      if(i == SCP_MAX_ZONES - 1) idl = nid;
     }
   ScpZone f5, fl, fx;
   Ac(SZN2.Find(id5, f5) && MathAbs(f5.bottom - 100.05) < 1e-8 && SZN2.Find(idl, fl) &&
      MathAbs(fl.bottom - (100 + (SCP_MAX_ZONES - 1) * 0.01)) < 1e-8 && !SZN2.Find(-105, fx) && !SZN2.Find(idl + 999, fx),
      "RF08", "tra vùng theo mã nhanh cho kết quả đúng như dò tuần tự");
   Ac(SZN2.Count() == SCP_MAX_ZONES && SZN2.Dropped() - dropped0 == 1, "RF04", "vùng vượt sức chứa bị bỏ và được đếm",
      "count=" + IntegerToString(SZN2.Count()) + " dropped=" + IntegerToString(SZN2.Dropped() - dropped0));
   SZN2.Init();

   // RF05: mốc bảo vệ giá vào = max(2,5 giá, 1R khoảng dừng).
   ScpFakeMoney money;
   ScpPlanBuilder pb; pb.Init(GetPointer(money), 0.25, 1.2, 0, 2.5, 1.0);
   ScpProposal pp; ZeroMemory(pp);
   pp.scenario = SCP_SC_S01; pp.zone_id = 1; pp.episode_id = 1; pp.entry_tf = SCP_TF_M1; pp.management_tf = SCP_TF_M1;
   pp.direction = +1; pp.thesis = SCP_THESIS_LOCAL_REACTION; pp.reaction = SCP_RE_P1;
   pp.reaction_known_at = D'2026.01.05 10:00'; pp.invalidation = 97.60; pp.target_zone_id = 2; pp.target_edge = 110.00;
   pp.atr_ref = 1.0; pp.atr_m1 = 1.0; pp.reaction_bid = 100.55; pp.confirmation_edge = 100.40;
   ScpQuote pq; pq.bid = 100.55; pq.ask = 100.75; pq.time = pp.reaction_known_at;
   ScpSymbolSpec sp; sp.symbol = "XAUUSDm"; sp.tick_size = 0.01; sp.point = 0.01; sp.digits = 2; sp.volume_min = 0.01;
   sp.volume_max = 100; sp.volume_step = 0.01; sp.stops_level_points = 0; sp.spread_now = 0.20; sp.commission_per_lot = 0;
   ScpPlan plan; ENUM_SCP_SKIP skip; string why = "";
   bool ok = pb.Build(pp, pq, sp, plan, skip, why);
   Ac(ok && MathAbs(plan.breakeven_trigger - 3.35) < 1e-6, "RF05a", "dừng 3,35 giá thì bảo vệ giá vào ở 3,35 (1R), không phải 2,5",
      "ok=" + (ok ? "true" : "false") + " be=" + DoubleToString(plan.breakeven_trigger, 3) + " " + why);
   pp.invalidation = 99.60;
   pp.target_edge = 105.00;
   ScpPlanBuilder pb1; pb1.Init(GetPointer(money), 0.25, 1.2, 0, 2.5, 1.0);
   ok = pb1.Build(pp, pq, sp, plan, skip, why);
   Ac(ok && MathAbs(plan.breakeven_trigger - 2.5) < 1e-6, "RF05b", "dừng ngắn 1,35 giá thì vẫn giữ mốc 2,5 giá",
      "ok=" + (ok ? "true" : "false") + " be=" + DoubleToString(plan.breakeven_trigger, 3) + " " + why);

   // RF06: thoát vì mất mốc vô hiệu chỉ khi nến đóng qua mốc, không phải khi râu chạm mốc.
   datetime opened = D'2026.01.09 10:00:30';
   ScpBar wick = MkBar(D'2026.01.09 10:01', 100.5, 100.8, 99.50, 100.3);
   ScpBar close_below = MkBar(D'2026.01.09 10:01', 100.5, 100.6, 99.40, 99.55);
   ScpBar before = MkBar(D'2026.01.09 09:59', 100.5, 100.6, 99.40, 99.55);
   Ac(!ScpInvalidationClosed(wick, 1, 99.60, opened), "RF06a", "mua: râu xuống quá mốc rồi đóng lại trên mốc thì giữ lệnh");
   Ac(ScpInvalidationClosed(close_below, 1, 99.60, opened), "RF06b", "mua: nến đóng dưới mốc thì thoát");
   Ac(!ScpInvalidationClosed(before, 1, 99.60, opened), "RF06c", "không dùng nến đóng trước lúc khớp");
   ScpBar sell_close = MkBar(D'2026.01.09 10:01', 100.5, 101.0, 100.4, 100.9);
   Ac(ScpInvalidationClosed(sell_close, -1, 100.80, opened) && !ScpInvalidationClosed(wick, -1, 100.80, opened),
      "RF06d", "bán đối xứng");

   // RF07: siết dừng theo cấu trúc chỉ sau khi đã đi thuận 1R.
   Ac(!ScpTrailAllowed(2.0, 3.0, 1.0) && ScpTrailAllowed(3.0, 3.0, 1.0), "RF07a", "chưa đủ 1R không siết; đủ 1R thì siết");
   Ac(ScpTrailAllowed(0.5, 3.0, 0.0) && ScpTrailAllowed(0.5, 0.0, 1.0), "RF07b", "tắt công tắc hoặc thiếu dữ liệu cũ thì như cách cũ");
  }

void OnStart()
  {
   Print("== ScpVerify SCP-MTF-1.0 ==");
   TestPivotConfirmation();
   TestDirectionAndTransition();
   TestEmaSeed();
   TestZoneAndEpisode();
   TestReactionPatterns();
   TestScenarios();
   TestScenarioSell();
   TestBreakBranches();
   TestRangeBranch();
   TestEmaBranch();
   TestImpulseBranch();
   TestBarRejects();
   TestPlanMoney();
   TestReviewRegressions();
   TestFalseBreakAndValidity();
   TestIndicatorsLongRun();
   TestIndependentCandidates();
   TestPriceManagement();
   TestReentryAfterExpired();
   TestProfitProtection();
   TestReviewFixes();
   Print("Tổng: ", g_run, " ca | PASS ", g_pass, " | FAIL ", g_fail);
   if(g_fail > 0)
      Print("CA LỖI:\n", g_failList);
   if(InpCloseTerminal)
      TerminalClose(0);
  }
