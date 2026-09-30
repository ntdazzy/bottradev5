// Kiểm tra các quy tắc thuần bằng MQL5 trong MT5, không gửi lệnh.
#property script_show_inputs
#include <BotVang/ScalpSignal.mqh>

input bool InpCloseTerminal = false;
int passed = 0, failed = 0;
void Check(bool ok, string name)
  {
   if(ok) passed++;
   else { failed++; Print("[ScalpVerify] FAIL ", name); }
  }
bool Equal(double a, double b) { return MathAbs(a - b) < 0.000001; }
void SeedContext(CScalpContext &ctx)
  {
   ctx.Init();
   MqlRates r; ZeroMemory(r); r.open = r.close = 100; r.high = 100.3; r.low = 99.7; r.tick_volume = 100;
   for(int i = 0; i < 21; i++)
     { r.time = D'2026.01.01' + i * 60; ctx.bars.Add(r); ctx.force.Add(r); }
   ArrayResize(ctx.zones.z, 1); ctx.zones.n = 1;
   ZeroMemory(ctx.zones.z[0]);
   ctx.zones.z[0].id = 700; ctx.zones.z[0].type = ZT_FVG; ctx.zones.z[0].dir = 1;
   ctx.zones.z[0].top = 99.5; ctx.zones.z[0].bottom = 98.8; ctx.zones.z[0].k0 = -1;
   ctx.htf.T[1].st.trend = 1; ctx.htf.T[2].st.trend = ctx.htf.T[3].st.trend = -1;
  }
void OnStart()
  {
   Check(Equal(ScalpNetRatio(1, 100.0, 98.0, 105.0, 0.5), 1.5), "buy net costs once");
   Check(Equal(ScalpNetRatio(-1, 100.0, 102.0, 95.0, 0.5), 1.5), "sell symmetric net costs");
   Check(ScalpNetRatio(1, 100, 101, 105, 0.5) == 0, "invalid stop rejected");
   Check(ScalpNetRatio(1, 100, 98, 100.4, 0.5) == 0, "reward consumed by cost rejected");
   Check(ScalpTightens(1, 98, 100, 102, 0.3), "buy breakeven allowed");
   Check(!ScalpTightens(1, 100, 99, 102, 0.3), "buy stop never widened");
   Check(ScalpTightens(-1, 102, 100, 98, 0.3), "sell breakeven allowed");
   Check(!ScalpTightens(-1, 100, 101, 98, 0.3), "sell stop never widened");
   Check(!ScalpTightens(1, 98, 101.9, 102, 0.3), "broker distance respected");
   SmcZone ageZone; ZeroMemory(ageZone); ageZone.type = ZT_FVG; ageZone.born = 0;
   Check(!ScalpZoneExpired(ageZone, 500) && ScalpZoneExpired(ageZone, 501), "FVG expires before intrabar use");
   ageZone.type = ZT_OB;
   Check(!ScalpZoneExpired(ageZone, 300) && ScalpZoneExpired(ageZone, 301), "OB age boundary");
   ageZone.type = ZT_MSNR;
   Check(!ScalpZoneExpired(ageZone, 99) && ScalpZoneExpired(ageZone, 100), "MSNR age boundary");
   Check(ScalpGap(100, 403, 300) && !ScalpGap(100, 103, 300), "missing full candle blocks delayed signal");
   ScalpSignal s; ZeroMemory(s);
   double boundary = ScalpEntryBoundary(1, 98, 105, 0.5, 1.2);
   Check(Equal(ScalpNetRatio(1, boundary, 98, 105, 0.5), 1.2), "buy boundary includes costs exactly");
   Check(ScalpNetRatio(1, boundary + 0.01, 98, 105, 0.5) < 1.2, "buy above boundary is chasing");
   boundary = ScalpEntryBoundary(-1, 102, 95, 0.5, 1.2);
   Check(Equal(ScalpNetRatio(-1, boundary, 102, 95, 0.5), 1.2), "sell boundary symmetric");
   Check(ScalpNetRatio(-1, boundary - 0.01, 102, 95, 0.5) < 1.2, "sell below boundary is chasing");
   Check(ScalpBiasAllowed(1, 1) && ScalpBiasAllowed(-1, -1), "trade follows H1");
   Check(!ScalpBiasAllowed(1, -1) && !ScalpBiasAllowed(-1, 1) && !ScalpBiasAllowed(1, 0), "opposite or missing H1 blocks entry");
   SmcBar b; ZeroMemory(b); b.o = 101; b.h = 101.3; b.l = 98; b.c = 101.2; b.atr = 2;
   Check(ScalpLongWick(1, b, b.atr), "long lower wick is rebound");
   Check(!ScalpLongWick(-1, b, b.atr), "same candle not bearish wick");
   SmcBar previous = b; previous.h = 101.1; previous.l = 99;
   Check(ScalpPriceConfirmed(1, previous, b), "rebound breaks previous M1 high");
   previous.h = b.c;
   Check(!ScalpPriceConfirmed(1, previous, b), "touching previous high is not a break");
   previous.h = 102;
   Check(!ScalpPriceConfirmed(1, previous, b), "wick without price confirmation rejected");
   SmcZone revisit; ZeroMemory(revisit); revisit.dir = 1; revisit.bottom = 98; revisit.top = 99;
   revisit.k0 = 10; revisit.fired = 7;
   SmcBar away = b; away.l = 99.5;
   Check(!ScalpRearm(revisit, away, 11), "cannot reset old reaction window");
   Check(!ScalpRearm(revisit, b, 12), "cannot reset while candle still touches zone");
   Check(ScalpRearm(revisit, away, 12) && revisit.k0 == -1 && revisit.fired == 0, "full departure allows fresh touch");
   revisit.dir = -1; revisit.top = 103; revisit.bottom = 102; revisit.k0 = 10; revisit.fired = 7;
   Check(ScalpRearm(revisit, b, 12), "sell departure symmetric");
   CScalpForce force; force.Init();
   MqlRates r; ZeroMemory(r); r.open = r.close = 100; r.high = 101; r.low = 99; r.tick_volume = 100;
   for(int i = 0; i < 21; i++) { r.time = D'2026.01.01' + i * 60; force.Add(r); }
   Check(force.Ready() && Equal(force.rsi, 50) && Equal(force.activity, 1), "flat RSI and volume baseline");
   r.close = 101; r.tick_volume = 200; force.Add(r);
   Check(Equal(force.activity, 2), "volume excludes current candle from baseline");
   double before = force.rsi;
   Check(force.AtPrice(100) < before && Equal(force.rsi, before), "provisional RSI does not mutate closed data");
   CScalpContext ctx; ctx.Init();
   ctx.bars.Add(r);
   ArrayResize(ctx.zones.z, 3); ctx.zones.n = 3;
   for(int i = 0; i < 3; i++)
     {
      ZeroMemory(ctx.zones.z[i]); ctx.zones.z[i].type = ZT_FVG; ctx.zones.z[i].dir = -1; ctx.zones.z[i].born = 0;
      ctx.zones.z[i].bottom = 105 + i * 3; ctx.zones.z[i].top = 106 + i * 3;
     }
   ScalpPlan p;
   Check(ctx.Target(1, 100.3, 0.3, 2, p) && Equal(p.obstacle, 105) && Equal(p.tp, 104.7), "nearest resistance wins");
   ArrayResize(ctx.htf.z, 1); ctx.htf.n = 1; ZeroMemory(ctx.htf.z[0]);
   ctx.htf.z[0].s.dir = -1; ctx.htf.z[0].s.bottom = 90; ctx.htf.z[0].s.top = 110; ctx.htf.z[0].tf = 2;
   Check(ctx.Target(1, 100.3, 0.3, 2, p) && Equal(p.obstacle, 105) && p.contextInside == 1,
         "inside broad H4 context does not veto local M1 target");
   ctx.htf.z[0].s.bottom = 103;
   Check(ctx.Target(1, 100.3, 0.3, 2, p) && Equal(p.obstacle, 103), "nearby H4 edge ahead still caps target");
   ctx.htf.n = 0;
   ctx.zones.z[0].bottom = 99;
   Check(!ctx.Target(1, 100.3, 0.3, 2, p), "inside opposing zone cannot skip to distant target");
   for(int i = 0; i < 3; i++)
     {
      ctx.zones.z[i].dir = 1; ctx.zones.z[i].top = 95 - i * 3; ctx.zones.z[i].bottom = 94 - i * 3;
     }
   Check(ctx.Target(-1, 100, 0.3, 2, p) && Equal(p.obstacle, 95) && Equal(p.tp, 95.6), "sell target converted to ask");
   ctx.zones.n = 0;
   Check(!ctx.Target(1, 100, 0.3, 2, p), "no obstacle no invented target");
   ctx.zones.n = 2;
   ZeroMemory(ctx.zones.z[0]); ctx.zones.z[0].type = ZT_FVG; ctx.zones.z[0].dir = 1;
   ctx.zones.z[0].id = 7; ctx.zones.z[0].bottom = 98; ctx.zones.z[0].top = 99;
   ZeroMemory(ctx.zones.z[1]); ctx.zones.z[1].type = ZT_SNR; ctx.zones.z[1].dir = -1;
   ctx.zones.z[1].id = 8; ctx.zones.z[1].bottom = 105; ctx.zones.z[1].top = 106;
   ZeroMemory(s); s.valid = true; s.dir = 1; s.zoneId = 7; s.zoneType = ZT_FVG;
   s.base = 98; s.atr = 2; s.top = 99; s.bottom = 98;
   ctx.htf.T[1].st.trend = 1;
   MqlTick tick; ZeroMemory(tick); tick.bid = 101; tick.ask = 101.3;
   string why;
   Check(!ctx.Plan(s, tick, SCALP_MARKET, 0.5, 1.2, p, why), "market chasing price rejected by net ratio");
   Check(ctx.Plan(s, tick, SCALP_AUTO, 0.5, 1.2, p, why) && p.limit && p.entry > 99.3 && p.ratio >= 1.2,
         "auto waits only as deep as cost and risk require");
   Check(ctx.Plan(s, tick, SCALP_LIMIT, 0.5, 1.2, p, why) && p.limit && Equal(p.sl, 97.7), "stop outside source zone with spread buffer");
   ctx.htf.T[1].st.trend = -1;
   Check(!ctx.Plan(s, tick, SCALP_AUTO, 0.5, 1.2, p, why), "H1 changed between signal and send blocks plan");
   ctx.htf.T[1].st.trend = 1;
   s.base = 90;
   Check(!ctx.Plan(s, tick, SCALP_MARKET, 0.5, 1.2, p, why), "distant stop disallows market entry");
   Check(!ctx.Plan(s, tick, SCALP_AUTO, 0.5, 1.2, p, why), "wide stop cannot force pending outside valid source zone");
   s.base = 98;
   ctx.Used(s);
   Check(ctx.zones.z[0].fired == 7, "accepted setup consumes all reactions for same zone");
   ctx.zones.z[0].dir = -1;
   Check(!ctx.Plan(s, tick, SCALP_LIMIT, 0.5, 1.2, p, why), "flipped source cancels eligibility");
   ctx.zones.z[0].top = 102; ctx.zones.z[0].bottom = 101;
   ctx.zones.z[1].dir = 1; ctx.zones.z[1].top = 95; ctx.zones.z[1].bottom = 94;
   ctx.htf.T[1].st.trend = -1;
   s.dir = -1; s.top = 102; s.bottom = 101; s.base = 102;
   tick.bid = 99; tick.ask = 99.3;
   Check(ctx.Plan(s, tick, SCALP_AUTO, 0.5, 1.2, p, why) && p.limit && Equal(p.sl, 102.6) && p.ratio >= 1.2,
         "sell waiting boundary and ask stop symmetric");
   tick.bid = 101; tick.ask = 101.3;
   Check(ctx.Plan(s, tick, SCALP_AUTO, 0.5, 1.2, p, why) && !p.limit, "good sell price enters immediately without deep pullback");

   CScalpContext fresh; SeedContext(fresh);
   r.time = D'2026.01.01 00:21'; r.open = 100; r.high = 101.2; r.low = 99; r.close = 101; r.tick_volume = 10;
   fresh.Add(r, s);
   Check(s.valid && !s.htf && s.zoneTf == -1 && s.biasH1 == 1 && s.biasH4 == -1 && s.biasD1 == -1,
         "M1 reaction needs no M15 touch or H4 D1 agreement or high activity");
   Check(s.touch == r.time && s.known <= s.touch, "touch and zone timing are causal");
   fresh.Used(s);
   r.time += 60; r.open = 101; r.low = 99.2; r.high = 102; r.close = 101.8;
   fresh.Add(r, s);
   Check(!s.valid, "same visit cannot trade another reaction");
   r.time += 60; r.open = 101.8; r.low = 100; r.high = 102.1; r.close = 102;
   fresh.Add(r, s, false);
   Check(fresh.zones.z[0].k0 != -1, "occupied account cannot rearm zone");
   r.time += 60; fresh.Add(r, s, true);
   Check(fresh.zones.z[0].k0 == -1 && fresh.rearmed == 1, "flat account plus departure rearms zone");
   r.time += 60; r.open = 102; r.low = 99; r.high = 104; r.close = 103.8;
   fresh.Add(r, s);
   Check(s.valid && s.zoneId == 700 && s.touch == r.time, "same zone can enter on genuinely new visit");
   SeedContext(fresh); fresh.zones.n = 0;
   fresh.Add(r, s);
   Check(!s.valid, "no known M1 zone cannot invent an entry from a new zone");
   SeedContext(fresh); fresh.htf.T[1].st.trend = 0;
   fresh.Add(r, s);
   fresh.ConfirmBias(s);
   Check(!s.valid && fresh.biasBlocked > 0, "unknown H1 does not invent a direction");
   SeedContext(fresh); fresh.htf.T[1].st.trend = -1;
   r.time = D'2026.01.01 00:59'; r.open = 100; r.high = 101.2; r.low = 99; r.close = 101;
   fresh.Add(r, s);
   fresh.htf.T[1].st.trend = 1; // H1 vừa đóng được đồng bộ sau khi xét vùng ở đầu nến M1.
   Check(s.valid, "hour boundary must retain reaction until new closed H1 is available");
   fresh.ConfirmBias(s);
   Check(s.valid && s.biasH1 == 1, "hour boundary uses latest closed H1 for final decision");
   SeedContext(fresh); fresh.Add(r, s); fresh.htf.T[1].st.trend = -1; fresh.ConfirmBias(s);
   Check(!s.valid && fresh.biasBlocked == 1, "hour boundary rejects direction invalidated by new H1");
   SeedContext(fresh); fresh.htf.T[1].st.trend = -1;
   fresh.zones.z[0].dir = -1; fresh.zones.z[0].top = 101.2; fresh.zones.z[0].bottom = 100.5;
   r.time = D'2026.01.01 00:21'; r.open = 100; r.high = 100.9; r.low = 98.8; r.close = 99;
   fresh.Add(r, s);
   Check(s.valid && s.dir == -1 && s.touch == r.time, "closed sell reaction matches inverse buy rules");

   SeedContext(fresh);
   r.time = D'2026.01.01 00:21'; r.open = 100; r.high = 100.6; r.low = 98.9; r.close = 100.5;
   tick.time = r.time + 11;
   Check(!fresh.Early(r, tick, s), "early wick waits twelve seconds on M1");
   tick.time++;
   Check(fresh.Early(r, tick, s) && s.early && s.touch == r.time, "early wick uses current observed candle only");
   fresh.Used(s);
   Check(!fresh.Early(r, tick, s), "accepted intrabar visit cannot resend");
   SeedContext(fresh); fresh.bars.b[0].t = r.time;
   Check(!fresh.Early(r, tick, s), "zone not known at candle open cannot trigger early entry");
   SeedContext(fresh); SmcBar recent = fresh.bars.b[20];
   ArrayResize(fresh.bars.b, 502); fresh.bars.n = 502; fresh.bars.b[501] = recent;
   Check(!fresh.Early(r, tick, s), "expired M1 zone cannot trigger early entry");
   SeedContext(fresh); fresh.zones.z[0].k0 = 19;
   Check(!fresh.Early(r, tick, s), "old visit is not a fresh early entry");
   SeedContext(fresh); fresh.htf.T[1].st.trend = -1;
   fresh.zones.z[0].dir = -1; fresh.zones.z[0].top = 101.2; fresh.zones.z[0].bottom = 100.5;
   r.open = 100; r.high = 101.1; r.low = 99.4; r.close = 99.5;
   Check(fresh.Early(r, tick, s) && s.dir == -1, "sell intrabar wick mirrors buy");

   previous.o = 100; previous.c = 101; previous.h = 101.2; previous.l = 99.8;
   b.o = 101.1; b.c = 99.7; b.h = 101.2; b.l = 99.5; b.atr = 1;
   Check(ScalpStrongReverse(1, previous, b, false, 0), "strong M1 engulf exits without RSI or distant barrier");
   Check(!ScalpStrongReverse(1, previous, b, false, 0, false), "pre-fill candle is not post-fill engulf evidence");
   b.o = 100.1; b.c = 100; b.h = 100.2; b.l = 99.9;
   Check(!ScalpStrongReverse(1, previous, b, false, 0), "small red candle does not force exit");
   Check(ScalpStrongReverse(1, previous, b, false, 100.05), "close through new protection exits");
   b.o = 100.1; b.c = 100; b.h = 101.5; b.l = 99.9;
   Check(ScalpStrongReverse(1, previous, b, true, 0), "strong rejection at obstacle exits on first full M1 after fill");

   CSmcBars swings; swings.Init();
   ZeroMemory(r); r.open = r.close = 101; r.high = 102; r.tick_volume = 100;
   for(int i = 0; i < 5; i++)
     {
      r.time = D'2026.01.01' + i * 60; r.low = i == 2 ? 99 : 100;
      swings.Add(r);
      if(i == 3) Check(ScalpMicroSwing(swings, 1, D'2026.01.01') == 0, "pivot cannot use future confirmation candle");
     }
   Check(Equal(ScalpMicroSwing(swings, 1, D'2026.01.01'), 99), "pivot becomes available after two right candles");
   Check(ScalpMicroSwing(swings, 1, D'2026.01.01 00:03') == 0, "pre-fill pivot cannot tighten new trade");
   string summary = StringFormat("PASS %d; FAIL %d", passed, failed);
   Print("[ScalpVerify] ", summary);
   int f = FileOpen("BotScalpPhanUng\\verify.txt", FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON, 0, CP_UTF8);
   if(f != INVALID_HANDLE) { FileWriteString(f, summary); FileClose(f); }
   else Print("[ScalpVerify] file_open_failed err=", GetLastError());
   if(InpCloseTerminal) TerminalClose(failed > 0 ? 1 : 0);
  }
