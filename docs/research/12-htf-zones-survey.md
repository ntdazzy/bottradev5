# Khảo sát cản khung lớn trong 51 chỉ báo TradingView đã tải (28/09/2026)

Nguồn: `docs/pine/tradingview/`. Kết quả dùng để viết SPEC mục 23. Chỉ tóm tắt cách làm, không chép mã.

## 1. Hỗ trợ/kháng cự, mức quan trọng, pivot, fractal

**Survey of S/R, key-level, pivot and fractal methods in the 51 downloaded scripts** (read-only; base path `docs/pine/tradingview/`)

The FVG/BPR, OB-lifecycle and candle-pattern scripts are left out of the table. They only matter here for how they request higher-timeframe data (Table B).

**Table A. Scripts that produce S/R levels, key levels, pivots or fractals**

| Script (file:lines) | Level source | Level → zone | Merge / strength / limits | Invalidation | HTF request and repaint |
|---|---|---|---|---|---|
| `pa/Support and Resistance Levels with Breaks [LuxAlgo].pine:12-29` | Pivot 15/15 on high/low, delayed one more bar, so known at p+16 | Line only | No merge. Only the latest pivot per side. Break mark needs a volume filter (EMA5 vs EMA10 of volume > 20) | None. The next pivot replaces the level. "Break" = close crosses the level | No HTF. Plot is shifted back 16 bars (backpainted). Break marks are not gated on bar close |
| `pa/Support Resistance Channels.pine:31-187` | Pivot 10/10 on high/low, or on the body | Channel = [min, max] of all pivots within a width of 5% of the 300-bar range (:41-43) | Strength = 20 per pivot + number of bars in the last 290 whose high or low sits in the channel (:99-107). Greedy pick of the strongest; overlapping channels dropped; top 6 shown. Min strength 1 = 20 points, so a single pivot passes (the tooltip says 2 are needed) | Nothing stored. Channels are recomputed only when a new pivot appears (:88). "Broken" = close crosses an edge while price is outside every channel | No HTF. Boxes extend both ways, so the current set is painted over all history. Uses the forming bar |
| `pa/Support Resistance with Breaks and Retests.pine:35-152` | Pivot 20/20 | From the pivot extreme to the more extreme neighbour candle. Resistance = [max(high p−1, high p+1), high p] (:39-40) | One box per side. An unbroken box is deleted when a new pivot arrives (:89-96) | Break = close (or wick) through the far edge. Retest = wick back into the box at least 3 bars later, confirmed within 2 bars | No HTF. Default mode "Repainting On" (uses the live close). "Candle Confirmation" mode does not repaint. Box drawn back to bar p |
| `pa/Breakout Finder.pine:15-68` | Pivot 5/5, kept 200 bars | Band = [highest pivot − 3% of the 300-bar range, highest pivot] | Needs at least 2 pivots in the band | Signal only | No HTF |
| `liquidity/Liquidity Swings [LuxAlgo].pine:13-210` | Pivot 14/14 | "Wick Extremity" = [max(o,c), high] of the pivot candle (support mirrored), or the full candle range | Touches = bars overlapping the zone, counted 14 bars late and including the pivot's own right-side bars. Optional filter by intrabar volume. Only the latest pivot per side | Close beyond the wick extreme ends it | Uses lower-timeframe data only, for volume. No bar-close gate. Drawn back to bar p |
| `liquidity/Liquidity Sweeps [LuxAlgo].pine:15-149` | Pivot 5/5; every unbroken pivot is kept | Line | None; max age 2000 bars | Close through = broken. Wick through + close back = one sweep. In "outbreak & retest" mode a broken level switches side and can be swept from the other side | No HTF. No bar-close gate |
| `liquidity/Pure Price Action Liquidity Sweeps [LuxAlgo].pine:40-120` | Recursive 3-bar fractal, depth 1–3 (short / intermediate / long term) | Line | None; 2000 bars | Close through; one wick sweep per level | No HTF. Lag varies: a level is known only when the next fractal forms |
| `liquidity/Buyside & Sellside Liquidity [LuxAlgo].pine:10-298` | Pivot 7/1 zigzag (50 swings) | Zone = mid of the cluster ± 0.69×ATR10 | Needs 3 or more swings within ±0.69×ATR10 (:149-172). 3 visible. "Present" mode = last 500 bars | Wick through the top = breached. A ±2.3×ATR breach zone is then tracked | No HTF. Output depends on where the chart ends. Box is resized after the fact |
| `fvg/ICT Concepts [LuxAlgo]…pine:63,351-401,771-857` | Pivot 5/1 zigzag | ± 0.4×ATR10 | 3 or more pivots in the cluster. NWOG/NDOG gap boxes (Friday close vs Monday open, previous close vs today's open) from chart bars | Close beyond both edges | No HTF |
| `liquidity/Equal HighLow (EQHEQL) [AlgoAlpha].pine:29-106` | Two adjacent candles with equal highs, tolerance 0.05×EMA500 of the average bar-to-bar change, plus an RSI filter | [max body of the two, max high] | Max age 1000 bars | Close through (default), 2 closes, or wick | Bug: turning the RSI filter off creates no zones (:37-40) |
| `liquidity/Supply and Demand Zones [BigBeluga].pine:32-137` | Opposite-colour base candle before 3 same-colour candles with volume above the 1000-bar average | Fixed 2×ATR200 box hanging from the base candle | On overlap one zone is deleted; max 5 per side; 14-bar cooldown | Close beyond the far edge | No HTF |
| `liquidity/Supply and Demand Visible Range [LuxAlgo].pine:77-167` | Volume in the visible chart range | Top and bottom bands holding ≥10% of volume (50 bins) | — | — | Repaints by design |
| `liquidity/Liquidity Grabs Flux Charts.pine:17-78` | Pivot 25/25 | Line | 5 levels per side | Body beyond = level dead. Wick beyond + body inside = grab | Gated on bar close |
| `liquidity/Swing Failure Pattern (SFP) [LuxAlgo].pine:106-109` | Pivot 5/1, latest level only | Line | 500 bars | Close beyond | Lower-timeframe data for volume only |
| `smc/Market Structure (BOS CHOCH), Advanced & Improved.pine:30-50,177-217` | Swing pivot 25/25 (internal 5/5) | Liquidity line | 10 per side | Wick through = taken | No bar-close gate |
| `smc/Market Structure CHoCHBOS (Fractal) [LuxAlgo].pine:40-138` | 5-bar fractal (2 bars up, 2 down) | "Dynamic support" = lowest low between the fractal and the break bar | Latest only | Close through | — |
| `smc/Multi Length Market Structure (BoS + ChoCh).pine:8-23,142-160,317-335` | Pivots at lengths 5, 10, 15, 20, 30, 50 | Lines of unbroken pivots | Same exact price at several lengths is drawn once, labelled with the longest length (a strength measure) | Close through | — |
| `ob/Rejection Blocks [ICT].pine:4-150` | Pivot 3/3 whose wick ≥ 2×body, at least 0.5×ATR14 away from the previous same-side pivot | Wick part [body edge, extreme], plus a 50% line | The ATR spacing rule works as de-duplication | Close beyond the far edge. One retest flag | Gated on bar close |
| `ob/Higher order Orderblocks…pine:78-115` | 3-bar fractal, then second-order fractal (fractal of fractals) | [pivot high, max of the two candle lows] | 10 second-order pivots | Tested or broken judged by the next pivot, not by closes | Gated on bar close |
| `ob/Smart Money Concepts (SMC) [LuxAlgo]…pine:110-111,337-457,666-700,814-822` | One-sided swing (N = 50 swing, 5 internal, 3 for equal highs/lows) plus trailing extremes | Equal-high/low lines within 0.1×ATR200. Previous day/week/month high and low as lines | Strong/weak label from trend. Latest only | — | D/W/M levels: `[high[1], low[1]]` with lookahead_on = previous closed bar, **correct**. Drawn on the last bar only |
| `msnr/MSnR Key Level [6 Types].pine:17,104-113,176,249-293` | Two-candle colour pair (A, V, gaps), price = first candle's close | Line | Scans 25 closed bars | Flips each time a candle of the right colour closes through | No repaint: rebuilt from closed bars |
| `msnr/MSnR Double Breakout Level.pine:69-71` | A/V staircase; the level is A2 or V2 after a close beyond A1 or V1 | Line | 200 bars, 6 levels | — | Close-only; relabelled later |
| `msnr/MSnR Classic StoryLine MTF.pine:90-199,532-542` | **HTF** (M, W, D, H4, H1) A/V/gap levels from closed candle pairs. Fresh until the first wick touch that closes back (tolerance ½ tick) | Line | 300 levels per HTF; window of 3000 bars counted from the last bar | Close through flips the level (SBR/RBS), fresh again | Request with lookahead off; the engine reads only bar [1] with a time guard. **No leak**, but on history it lags live by one HTF bar |
| `msnr/Malaysian SnR and Decision Levels [DoN].pine:10-132,143-337` | Chart TF: close pivot 3/3. **HTF (D default): close pivot 3/3**, last 3 per side. H4 "decision level" = open of the 2nd of two same-colour H4 candles | Chart TF: [close pivot, wick extreme]. HTF and decision levels: lines | 5 active per side; 3 HTF; 3 decision; 10 history | Close through becomes a history line; deleted when price closes back | HTF pivots requested without [1] → **repaints live** (phantom lines stay until reload). Decision level: [1] with lookahead off → history lags one H4 bar |
| For comparison, ours: `docs\pine\BotVang_SMC.pine:115-121,141-182`; `mql5\Include\BotVang\SmcZones.mqh:252-258`; `mql5\Include\BotVang\Zones.mqh:209-353` | Pivot rule ≥ left, > right. §22.1 SNR = **entry-TF pivot 5/5, zero-width line**. The old v1 engine: M15/H1/H4 A/V close pivot 3/3, gap, swing 5/5 (M15/H1), previous day high/low | v1: A/V band up to 0.5 ATR; swing ±0.15 ATR; previous day ±0.15 ATR D1 | v1: de-dup within 0.1 ATR; max 60 zones per TF | v1: close beyond far edge + tolerance, then flip | H1 trend: `[1]` + lookahead_on, **correct**. v1 reads closed HTF bars by time (Zones.mqh:343). Skips Saturday/Sunday D1 bars (:303-326) |

**Table B. How higher-timeframe data is requested, all scripts**

| Pattern | Scripts | Result |
|---|---|---|
| `expr[1]` + lookahead_on | SMC LuxAlgo D/W/M levels (:667); TFO IFVG (`fvg/Inverse FVG with Rejections [TFO].pine:38`, new HTF bar detected via timeframe.change); our `BotVang_SMC.pine:182` | Non-repainting; history and live match |
| lookahead_off, value taken from bar [1] | StoryLine (:532-542); DoN decision level (:259); QML FTB HTF EMA (`msnr/QML FTB…pine:299-301`) | No future leak, but history is one HTF bar later than live |
| lookahead_off, forming HTF bar | DoN HTF pivots (:161); `fvg/Fair Value Gap [LuxAlgo].pine:69`; Leviathan (`fvg/Gaps + Imbalances…pine:49-55`) | Repaints live; phantom zones stay until reload |
| lookahead_on on the forming bar `[0]` | SMC LuxAlgo HTF FVG (:635) | Leaks the future on history |
| HTF code present but unused | `ob/Volumized Order Blocks Flux Charts.pine:28,404-406` (timeframe fixed to chart TF) | This is the only script that merges zones across timeframes: any area overlap produces a union box (:352-400) |

**Conclusions**

1. **Common practice for the level itself:** a confirmed pivot N/N on high/low. Pine's rule is ≥ on the left bars, > on the right bars, and the pivot is only known at bar p+N. Default N varies: 5 (sweeps, fractals, Breakout Finder), 7/1 (buy/sell-side liquidity), 10 (SR Channels), 14 (Liquidity Swings), 15 (LuxAlgo S/R), 20 (HoanGhetti), 25 (Flux Grabs, Confluencer). The MSNR scripts use closes instead: DoN uses a close pivot 3/3, and the A/V scripts use the colour pair priced at the first candle's close. Most scripts keep only 1–10 levels per side, and several keep only the latest pivot per side.

2. **How a level becomes a zone, four families:**
   - Line only: the majority, including our §22.1 SNR.
   - The pivot candle's wick part: Liquidity Swings, Rejection Blocks, DoN, EQH/EQL.
   - An ATR band: ±0.69×ATR10 (buy/sell-side liquidity), ±0.4×ATR10 (ICT Concepts), a fixed 2×ATR200 box (BigBeluga), ±0.15 ATR in our old SPEC §5.1.
   - A percentage of the recent range: SR Channels 5% of 300 bars, Breakout Finder 3%.

   The wick part and the ATR band frozen at creation are fixed and objective. Range-percentage widths change with the window and cannot be compared across timeframes.

3. **Merging and strength are rare and loosely defined:**
   - Pivot clusters: SR Channels, buy/sell-side liquidity, ICT Concepts.
   - Equal highs/lows within 0.1×ATR200 (SMC LuxAlgo).
   - Exact-price dedup across pivot lengths (Multi Length).
   - Area-overlap union (Flux OB).
   - Only the MSNR scripts count a real "touch and close back" (fresh/unfresh).
   - Existing touch counters are late or inflated (Liquidity Swings :43-61).
   - SR Channels' minimum-strength setting does not enforce 2 pivots.

4. **Invalidation:** a close beyond the far edge is the dominant rule. A wick beyond is used only for "liquidity taken". A close-through flip (SBR/RBS) exists only in the MSNR scripts, DoN, and the outbreak mode of Liquidity Sweeps.

5. **Higher-timeframe S/R is almost absent.** Only three scripts do it:
   - SMC LuxAlgo: previous day/week/month high and low, correct method, lines only.
   - DoN: HTF close pivots, which repaint live.
   - StoryLine: an HTF MSNR engine with no leak.

   None builds HTF pivot zones with a width. None tests an entry-TF zone against an HTF zone. So "the way the indicators compute it" gives: pivots or A/V levels on closed HTF bars, plus previous day/week high and low.

6. **Non-repainting rules:**
   - Pine: use `expr[1]` with lookahead_on. With lookahead_off plus [1] there is no leak, but history lags live by one HTF bar. Without [1] the result repaints live; lookahead_on without [1] leaks the future.
   - MT5 equivalent: at each closed M1/M5 bar, read HTF bars by time up to the entry bar's open − 1 (as `Zones.mqh:343` already does). Each HTF object's known-time is the close of its confirming HTF bar.

7. **Best-defined non-repainting method to reuse** (our own code, pieces taken from the scripts above):
   - **Level:** Pivot(N,N) on closed M15/H1/H4/D1 bars, known at the close of bar p+N. Pivot lag is N × timeframe: N=5 on H4 is 20 hours, on D1 it is 5 trading days. Consider N=3 on H4/D1.
   - **Zone:** the pivot candle's wick part (Liquidity Swings "Wick Extremity"). Variant: ±0.15 ATR of that timeframe (old SPEC §5.1).
   - **Invalidation:** the first entry-TF close beyond the far edge.
   - **Previous day high/low:** the last completed D1 bar, skipping the ~2-hour Sunday D1 stub (Exness gold opens Sunday 22:05 server time; `docs\research\07-…:52`; `Zones.mqh:303-326` already does this).
   - **Previous week high/low:** W1 bar shift 1. I did not confirm which weekday MT5 W1 bars open on at Exness (the task says Monday; MT5 normally uses Sunday). Check with `iTime(W1, 0)` before relying on it.
   - **HTF OB/FVG:** the same OB-1/FVG-1 rules run on closed HTF bars.

8. **What the project computes today:**
   - §22/§24 zones use the entry timeframe only (`SmcZones.mqh:252-258`). SNR is a zero-width pivot 5/5 line with a 500-bar lifetime, about 8 hours on M1 and 42 hours on M5. There is no HTF, no merging and no strength.
   - The old engine `Zones.mqh` (SPEC §5/§6: M15/H1/H4 + previous day, timeframe weights, overlap within 0.3×ATR M15) already builds HTF zones without repainting. It found no edge on flip-retest events (`docs\HANDOFF.md:125-133`), but it was never tested with §22/§24 reaction entries.

9. **Overlap of an entry-TF zone with an HTF zone:** no script defines this for S/R. Usable definitions:
   - Price-interval intersection (Flux OB uses area overlap > 0%).
   - Distance ≤ k×ATR: 0.3×ATR M15 (SPEC §6.1), 0.1×ATR200 (SMC LuxAlgo equal highs/lows), 0.69×ATR10 (buy/sell-side liquidity).

   A zero-width HTF line needs a band before anything can overlap it, so the width choice sets the sample size.

10. **No script shows evidence** that HTF levels or confluence predict reactions (doc 10 §6; SPEC §6.2 citing Osler 2000). These are definitions to measure against the RC-T, X1 and X2 controls, not an edge.

## 2. OB, FVG, MSNR ở khung lớn

**HTF OB / FVG / MSNR survey: how 51 TradingView scripts compute them and what changes for our §21.2 zones (read-only)**

Before the owner's question can be answered: the trading method is already as he describes it. §22/§24 wait for price to reach a zone, wait for a reaction candle, enter at market, put the SL behind the wick and take TP at 1–5 price. But every zone is computed only on M1/M5 (SPEC §22.1). No higher-timeframe (HTF) zones exist yet, and neither do previous day/week high/low or any "zone overlaps an HTF zone" logic. H1 is used only as a direction filter (`docs/pine/BotVang_SMC.pine:141-182`, with [1] + lookahead_on, which is correct).

Paths are relative to `docs/pine/tradingview/`. S-numbers are from `docs/research/10-tradingview-smc-msnr-ob-fvg.md` §0.

| Script | How the HTF version is computed | When it becomes known | Zone bounds | Touch / invalidation | Lifetime | Repaint risk |
|---|---|---|---|---|---|---|
| **S21** LuxAlgo FVG, `fvg/Fair Value Gap [LuxAlgo].pine:15,44-69,104-146` | The whole pattern runs inside the HTF request; lookahead off, no [1] offset | History: at the HTF close. Live: while the HTF bar is still forming | [high c1, low c3]; middle candle must close beyond c1; size filter off by default | Removed on a **chart-timeframe close** through the far edge | Until invalidated | **Live repaint.** Zones from the forming HTF bar stay on the chart as phantoms |
| **S24** Leviathan MTF, `fvg/Gaps + Imbalances + Wicks (MTF) - By Leviathan.pine:49-55,173-190,236-260` | Reads raw HTF OHLC with lookahead off; checks on the first chart bar of each new HTF bar | History: one chart bar after the HTF close | FVG [h2, l]; no middle-candle filter; gap > 1×ATR30 of the HTF. Also HTF gap and wick zones | Default "Touch": the zone ends when a chart bar crosses either edge | Until the first touch; only the last 150 days by wall clock | **Live uses different candles** (k-1, k, forming k+1) than history (k-2, k-1, k) |
| **S25** TFO IFVG, `fvg/Inverse FVG with Rejections [TFO].pine:38,72-140` | Pulls the closed HTF bar ([1] + lookahead_on) and rebuilds up to 300 HTF bars itself | First chart tick after the HTF close, same on history and live | Candle-2 colour gives direction; candle 2 must span the gap; size > 0.3 × average HTF range | **HTF close** through the far edge turns it into an IFVG; the IFVG dies on an HTF close back through | Last 10 per list | **None.** This is the reference pattern |
| **S1** LuxAlgo SMC, HTF FVG, `ob/Smart Money Concepts (SMC) [LuxAlgo] (order block part only).pine:625-654` | lookahead_on, and reads the **current** HTF bar's high[0]/low[0] | At the first chart bar of candle 3 | [high c1, low c3]; size threshold depends on history | Bull removed on a chart wick below the bottom; **bear removed on first entry** | Until removed | **Future leak on history** |
| **S1** previous D/W/M high/low, same file `:666-703,815-822` | [1] + lookahead_on | At the period close | Previous period's high/low as lines | None | Only the latest level, drawn on the last bar | None, but no history is kept |
| **S1** OB, same file `:481-525` | Chart timeframe only | At the break bar | Lowest-low candle from the pivot bar up to the bar before the break (volatile bars have high/low swapped) | Wick through (default) or close | 100 stored per layer | Chart only |
| **S15** Flux Volumized OB, `ob/Volumized Order Blocks Flux Charts.pine:8-9,28,242-331,404-461` | Requests the whole OB list from another timeframe, but the timeframe is **hard-coded to the chart** | At the break close on the chart | Lowest-low candle between a one-sided swing (length 10) and the break; ≤ 3.5×ATR10 | Wick below the bottom (default) makes it a breaker; the breaker dies on high > top. Overlapping OBs from different timeframes are merged | 30 per side; only the last 1750 bars are processed | Not HTF-capable as downloaded |
| **S46** DoN, `msnr/Malaysian SnR and Decision Levels [DoN].pine:143-161,202-247,259-290` | Close-pivot 3/3 recomputed on D1 by default, lookahead off. H4 "decision level" read with [1] and lookahead off | Pivot: 3 HTF bars after the pivot bar | Single line at the close pivot. Decision level = open of the 2nd of two same-colour H4 candles | Flip on a **chart close**; the history line is deleted on a close back through | 3 lines per side, 10 history lines | **Live phantom pivots.** Decision level on history lags live by one H4 bar |
| **S47** MSnR StoryLine MTF, `msnr/MSnR Classic StoryLine MTF.pine:90-205,218-520,532-542` | The MSNR engine runs **on HTF bars**, only on the closed bar [1], with a time guard | Live: at the HTF close. History: about one HTF bar later | Level = close of the first candle of an A, V or gap pair, rounded to tick | ½-tick tolerance. A **fresh** level whose HTF wick touches and whose HTF close stays on its side counts as a rejection. An HTF close through flips it (SBR/RBS) and makes it fresh again. The lower timeframe then looks for the touch, locks the last A/V before it, and confirms on a close beyond that A/V | 300 levels per HTF; 12 pending setups | No leak |
| Chart-timeframe OBs: S2, S12, S13, S14, S16, S17, S18, S19, S20 | None built in; they could be run on an HTF chart | At the break close | See research §1.2 (S14 and S19 use bodies; S13 uses half the candle; S17's "higher order" means pivots of pivots, not a timeframe) | Wick, body or close, per research §1.2 | S16 processes only 2000 bars | Per research §4 |
| Chart-timeframe FVG / MSNR: S3, S22, S23, S26–S29, S41, S38, S36, S37, S40 | None built in (S40's HTF input is only an EMA bias) | At the candle-3 close, or the pair close | Per research §1.3 and §1.4 | S41 flips only on a close with the matching candle colour; 25-candle lifetime | — | S22 deletes past signals |

**Conclusions**

1. **Only two downloaded scripts compute HTF zones honestly: S25 and S47.** S25 takes the closed HTF bar with [1] + lookahead_on; S47 recomputes the rules on closed HTF bars. S1's HTF FVG leaks the future on history. S21, S24 and S46 read the still-forming HTF bar, so what they show live is not what appears after a reload. None of the downloaded scripts provides an HTF order block, because S15's multi-timeframe code is fixed to the chart timeframe. So "the way the indicators compute it" should mean: run our §21.2 definitions on closed M15/H1/H4/D1 bars (shift ≥ 1 in MQL5), and never on the forming bar.

2. **When an HTF object becomes known.** An HTF FVG or MSNR level is known at the HTF close. Anything pivot-based (OB-1, SNR, structure breaks) also waits N HTF bars for the pivot to confirm. The object can be used from the first M1/M5 bar that opens at or after that moment. The pivot wait grows fast:
   - Pivot 5/5: H1 = 5 h, H4 = 20 h, D1 = 5 days.
   - Pivot 20/20: H4 = 80 h, D1 = 20 days.
   - So on HTF, use only the internal layer (N = 5, or 3 as S46 does on D1). The 20/20 layer is impractical above M15/H1.

3. **Touch versus invalidation.** A wick touch is the same price event on any timeframe, because the HTF high is the maximum of the M1 highs. So "first touch" and "unfresh" can stay on M1/M5 wicks. Close-based states depend on the timeframe:
   - The indicators that do HTF properly (S25, S47, and the S42 rules) invalidate and flip on the **HTF close**.
   - S21 and S46 use the chart close, so one M1 close through an H4 FVG or level kills it early.
   - Recommendation: invalidate and flip on the HTF close by default, and measure the entry-timeframe close as a variant.

4. **Size filters and zone height.**
   - FVG-1's 0.25×ATR minimum and OB-1's 3.5×ATR cap must use a Wilder ATR computed on the HTF bars and frozen at creation. S24, S15 and S25 all size on the zone's own timeframe.
   - The gap-bar rule behaves differently on HTF bars. Gold's daily break (about 20:57–22:00 UTC) falls **inside** the Exness H4 20:00 bar and inside the D1 bar, so it is not flagged there. The weekend gap is still flagged.
   - HTF zones are many times taller than §24's 1–5 price TP. §22's "first touch at the near edge, reaction on k0 or k0+1" throws away reactions deeper in the zone. Indicators also track the midline (CE): S24 "Half Fill", S1's split box, S25's CE line. Measure near edge versus CE as variants.

5. **Lifetimes are counted in bars of the zone's own timeframe** in every indicator (S47: 300 levels, S15: 30, S25: 10, S46: 3). Our §22.1 bar counts become very different on HTF:
   - 500 bars ≈ 5 days on M15, ≈ 4 weeks on H1, ≈ 2 years on D1.
   - MSNR's 100 bars ≈ 4 days on H1, ≈ 3.5 weeks on H4, ≈ 5 months on D1.
   - Lifetime must be chosen per timeframe. "One zone, one trade per reaction type" still fits S47 (only a fresh level can produce a rejection) and S24 (the zone ends at first touch).

6. **MSNR on HTF.** The A/V pair rule and its price (close of the first candle) carry over unchanged.
   - S47 adds gap levels, a ½-tick tolerance, and rejection only on fresh levels, judged on the HTF candle. Our FU-1 has no tolerance (`BotVang_SMC.pine:441`).
   - A/V levels still appear about every second HTF bar, so the fresh filter matters most.
   - S46 uses a different source: close-pivots 3/3 on D1, which gives far fewer levels, plus the H4 decision level.
   - S47's story line (HTF fresh rejection, then lower-timeframe touch, lock the last A/V, close beyond it) is the MSNR version of our R4 (M5 zone, then M1 CHoCH).

7. **Overlap and confluence.** No downloaded script tests "an entry-timeframe zone inside an HTF zone". S15 only merges overlapping OBs from different timeframes for display, and S47 chains HTF to lower timeframe. For our test, define overlap as: when the M1/M5 zone becomes known, it intersects in price an HTF zone that was already known and not yet invalidated. Log both zones' IDs.

8. **Previous day/week high/low.** Only S1 computes it correctly ([1] + lookahead_on), and it keeps just the latest level with no touched/broken state. In MT5 it is the D1/W1 bar at shift 1, read at the first tick of the new period.

9. **MT5 candles will not match TradingView.** Exness runs on GMT+0, so D1 runs from UTC midnight. TradingView's XAUUSD feeds usually roll the day at 17:00 New York. D1/H4 candles, their A/V colours, D1 FVGs and PDH/PDL will therefore differ from what the owner sees on TradingView unless both use the same feed and session. Two things to check in the data:
   - Whether gold's Sunday-evening reopen creates a short Sunday D1 bar. If it does, Monday's "previous day" would be that stub.
   - Which day MT5 stamps the W1 bar with.

## 3. Đỉnh/đáy ngày trước, tuần trước

**Previous day/week high/low: how the scripts compute them, and a definition for Exness XAUUSDm**

Paths below are relative to the repository root. Scripts are under `docs\pine\tradingview\`.

| Source (file:lines) | Levels | Day/week boundary | How the data is read | Known from | Touch/break | Repaint / look-ahead |
|---|---|---|---|---|---|---|
| LuxAlgo SMC (`ob\Smart Money Concepts…pine` 121-129, 666-697, 814-822) | Previous day, week and month high/low | The feed's own TradingView session for D/W/M. On gold/FX CFD feeds this is normally the ~17:00 New York rollover; I could not check this offline. | `request.security(tf,[high[1],low[1],time[1],time],lookahead_on)`. Hidden when the chart timeframe is above the level's timeframe. On a D chart it shows the forming bar's high/low. | First chart bar of the new D/W/M bar | None. Two lines extend right and are replaced each period. Only the latest pair is drawn. | Correct pattern (offset [1] with lookahead_on). No history is kept, so it can't be backtested from the chart. The same file's higher-timeframe FVG (line 635) reads `high[0]/low[0]` with lookahead_on, which leaks the future. |
| LuxAlgo ICT Concepts (`fvg\ICT Concepts…pine` 219-223, 771-819) | NDOG = [previous-day close, day open]; NWOG = [Friday close, Monday open]; midpoint line | Calendar day in the exchange time zone via `ta.change(dayofweek)`, not the session rollover | Chart bars only. The comment on line 222 calls `close[1]` "Previous Day Open". | First bar of the new calendar day / first Monday bar | None. Boxes extend right; keeps 3 NWOG and 1 NDOG. | Stable. On 24-hour feeds, midnight is not the daily break, so the "gap" is not the real break or weekend gap. |
| ICT Concepts killzones (537-541) | NY 07-09, London 07-10 and 15-17, Asia 10-14 | IANA time zones, so DST is automatic | `time(tf, session, tz)` | Live | Background colour only; no session high/low | None |
| TFO IFVG (`fvg\Inverse FVG…TFO.pine` 20, 36-38, 72) | Higher-timeframe bars plus a session filter | Session in America/New_York | `[1]` + lookahead_on + gaps_off, and `timeframe.change` | New higher-timeframe bar | – | Correct |
| MSnR StoryLine (`msnr\…StoryLine MTF.pine` 114-122, 529-542), Malibu QML (283-301), DoN decision levels (259) | MSNR state on M/W/D/H4/H1, HTF EMA, H4 decision level | TradingView sessions | Reads only closed `[1]` (or `[1]`, `[2]`) with lookahead_off | Next higher-timeframe bar | StoryLine: fresh/touch/lock states | No leak. History lags live by one higher-timeframe bar. |
| DoN HTF pivots (161), Leviathan (49-55), LuxAlgo FVG (69), Flux OB (405) | HTF pivots, gaps, FVG, OB | TradingView sessions | Reads the forming higher-timeframe bar with lookahead_off | Inside the bar | – | Live values repaint until the higher-timeframe bar closes |
| TDH review (`docs\research\11-…md` 78, 105, 127) | Previous-day high/low and Asia/Europe/US session highs/lows as liquidity pools | Local session time zones | Python | – | Sweep = wick at least 1 tick beyond. Close back inside within 3 bars = reclaimed, otherwise consumed. | Measured gold break 20:57→22:00 UTC in September (US summer) |
| Ours: SPEC §5.1 / §6.1 / §16.8 + `Zones.mqh` 303-336, 419-429 | Previous-day high/low, band ±0.15 ATR(D1) | Broker D1 (server 00:00). Saturday and Sunday D1 bars are skipped. | `CopyRates(D1, dayOpen-1, 3)` | 00:00 server on weekdays. Friday's levels only arrive at Monday 00:00, so Sunday-evening hours still use Thursday's. | §5.3 states | No leak. The Sunday stub bar is never counted. There is no weekly level. PhanUngLab and SmcLab (§22.1) have no higher-timeframe levels. |
| Ours: `docs\pine\BotVang_SMC.pine` 141-182 | H1 trend and EMA | TradingView H1 | `[1]` + lookahead_on | Next H1 bar | – | Correct |

**What the survey shows**
1. **Only one of the 51 scripts draws previous day/week high/low (LuxAlgo SMC).** None has touch or break rules for them, none handles the gold daily break or weekends, and none lets you pick the day boundary. "Compute it like the indicators" therefore means only this: the high/low of the last completed D or W bar, available from the first bar of the new period. Touch and break rules must be our own.
2. **Even LuxAlgo uses two different "days".**
   - SMC takes the session day from `request.security('D')`.
   - ICT Concepts takes the calendar midnight from `ta.change(dayofweek)`.
   - An Exness D1 bar (00:00–24:00 server) contains the daily break plus 1–2 hours of the next New York session. A TradingView gold CFD day normally ends at the break.
   - Levels only differ when the day's extreme prints in that post-break window, but they will not always match a TradingView chart exactly.
3. **The break time moves with US daylight saving; 21:59–23:00 is the winter time only.**
   - Winter (in our data 05/01–06/03/2026, and again from 01/11/2026): about 21:58–23:01.
   - Summer (from 08/03/2026): about 20:58–22:01. Sources: `docs\research\05-…md:224-225`, TDH's September measurement in `11-…md:127`.
   - The project already encodes this in `Signal.mqh:46-47` (`SessionShift`) and `Filters.mqh:27` (`UsDst`).
   - The tester's session table is fixed, so find the break from the data (a bar gap of 30 minutes or more) or reuse `SessionShift`. Never hard-code the time.

**Recommended definition for Exness XAUUSDm**

4. **Previous day (default, "A", broker D1 bars):**
   - Trading days are Monday to Friday. The short Sunday D1 bar (reopen 22:05/23:05 to 24:00) counts as part of Monday.
   - Day high/low for day d = high/low of trading day d−1. Monday and the Sunday stub use Friday. Tuesday uses Sunday stub plus Monday.
   - Read closed bars only: `CopyRates(PERIOD_D1, dayOpen-1, n)` as in `Zones.mqh:309`, or shift ≥ 1. Skip Saturday/Sunday bars, and add the Sunday bar when the previous weekday is Monday.
   - Known at 00:00 server (Tuesday to Friday). Friday's levels are known at the Sunday reopen. A level is usable from the first M1/M5 bar that opens at or after that time.
   - This differs from `Zones.mqh`, which ignores the Sunday bar and only uses Friday's levels from Monday 00:00. Either change it or measure the old way as a variant.
5. **Previous week:**
   - W1 shift 1 = the previous trading week (Sunday reopen to Friday close), known at the Sunday reopen.
   - The task text says W1 bars start Monday. I believe MT5 stamps W1 bars at Sunday 00:00, but have not verified it. Check that `iTime(_Symbol, PERIOD_W1, 0)` is a Sunday. If weeks started Monday, the Sunday stub would land in the previous week and must be moved.
   - Get the week start from `iTime`, not from `t/604800*604800`. The epoch started on a Thursday, so that division lands on Thursdays. It is fine for D1 only.
6. **Around the break (default A):** the break does not move the day boundary, but three rules apply.
   - The reopen bar is usually a gap bar (SPEC §21.1). A touch only counts if the touch bar opened on the correct side of the level (SPEC §5.4), so a gap straight through the day high is not a touch-and-reaction.
   - Keep raw highs/lows as the indicators do. Flag any extreme printed in the first 15 minutes after reopen or the last 30 minutes before the break (wide spread, Bid spikes), and measure with and without them.
   - The SPEC §12.1 blackout (30 minutes before the break, 15 minutes after reopen) also applies to reactions at these levels.
7. **Zone shape for §22/§24:**
   - Use a single level [L, L], like the SNR levels in §22.1. Previous-day/week high = resistance (sell), low = support (buy).
   - Only the first touch counts.
   - The level ends when a bar closes beyond it (variant: it flips role, like MSNR) or when the next day's or week's levels replace it.
   - Do not reuse the ±0.15 ATR(D1) band from §5.1. It is many times an M5 ATR and wider than the 1–5 price take-profit in §24.
8. **Variant "B" (to match TradingView and the ICT New-York-close day):**
   - The day runs from the first bar after the break to the start of the next break; Sunday reopen starts Monday's day. Build it from closed M1 bars and find the break by the bar gap.
   - Known at the start of the break, usable from the reopen. There is no Sunday-bar problem.
   - A level that price has already gapped through at reopen starts as broken and is not used.
   - Run A and B side by side. They only differ inside the post-break window.
9. **No look-ahead: MT5 equivalents of the Pine traps.**
   - Never use D1/W1 shift 0 as a level; that is the forming bar.
   - In pre-loaded history, never call `CopyRates(D1, t, 1)` with t inside the day. It returns the finished day, the same leak as LuxAlgo SMC line 635.
   - Build "today's high/low so far" and session highs/lows from closed M1/M5 bars only.
   - Store the time each level became known (doc 10 §2.0 rule 8). PhanUngLab already loads H1 bars this way (`PhanUngLab.mq5:128-133`).
10. **Related levels (optional, not requested):**
    - Daily/weekly open: use only as a bias filter (doc 10 lines 318 and 528).
    - Exness daily/weekly opening gaps should be [last close before break, first open after] and [Friday close, Sunday open], not LuxAlgo's calendar-midnight version.
    - If session highs/lows are ever needed, use DST-aware windows (as TDH and ICT Concepts do) instead of the fixed server hours in SPEC §16.8 (line 451).

Files:
- `docs\pine\tradingview\ob\Smart Money Concepts (SMC) [LuxAlgo] (order block part only).pine`
- `docs\pine\tradingview\fvg\ICT Concepts [LuxAlgo] (imbalance module FVG Implied FVG BPR Volume Imbalance).pine`
- `docs\pine\tradingview\msnr\MSnR Classic StoryLine MTF.pine`
- `docs\pine\tradingview\fvg\Inverse FVG with Rejections [TFO].pine`
- `mql5\Include\BotVang\Zones.mqh`
- `mql5\Include\BotVang\Signal.mqh`
- `mql5\Include\BotVang\Filters.mqh`
- `mql5\Experts\BotVang\PhanUngLab.mq5`
- `docs\SPEC.md`
- `docs\research\05-snr-fvg-ob-algorithms-exness-facts.md`
- `docs\research\10-tradingview-smc-msnr-ob-fvg.md`
- `docs\research\11-tradingdatahub-zones-review.md`

## 4. Ghi chú triển khai (tiếng Anh, cho người viết code)

**Scope.** Put the new code in `mql5/Include/BotVang/HtfZones.mqh` and wire it into `mql5/Experts/BotVang/PhanUngLab.mq5`. Add an input `InpHtf` (on/off) so regression checks can run.
- Reuse `CSmcBars`, `CSmcStructure` and `CSmcFvgs` from `SmcDetect.mqh`.
- Reuse the reaction predicates from `SmcZones.mqh`: `ZTouch`, `IsR1`, `IsR2`, `IsR3`, `EngulfShape`.
- Do **not** reuse `Zones.mqh`. It builds close-pivot A/V with ATR bands, uses SMA `iATR`, applies M5-close states and drops the Sunday D1 bar.

**1. One engine per HTF.** Write a class `CHtfTf` with:
- `tf`, `N` (5, 5, 3, 3), `P = PeriodSeconds(tf)`;
- `CSmcBars B`, `CSmcStructure st` (`Init(N)`), `CSmcFvgs fvg`;
- `datetime lastOpen`;
- for D1 only, a held weekend bar.

Use a class rather than a struct, because it holds class members. Do not create any zone until `B.Ready()` (14 bars). The FVG threshold (0.25 ATR) and the OB cap (3.5 ATR) then use that TF's own Wilder ATR automatically, because `CSmcFvgs` and `MakeOb` read `B.b[i].atr`.

**2. Reading HTF bars without look-ahead**
- **Closure rule.** For the entry bar opening at `te`, an HTF bar opening at `t_h` is usable only if `t_h + P <= te`. Apply this filter to every array `CopyRates` returns.
- **Warm-up.** Call `CopyRates(_Symbol, tf, 1, n, rates)`; shift 1 excludes the forming bar, and the closure filter still runs.
  - Suggested n: M15 1500, H1 1000, H4 700, D1 600.
  - Print how many bars came back and the first bar's time. The tester may hold less pre-start history than requested. Tick data starts 05/01/2026 (SPEC §16.8); older bars are whatever the terminal has.
- **Incremental.** Call `CopyRates(_Symbol, tf, lastOpen + 1, te - 1, rates)`. It returns bars whose open time falls in the range, and that includes the forming bar, so drop it with the closure rule.
  - If `CopyRates` returns -1 or `SERIES_SYNCHRONIZED` is false, do not advance `lastOpen`. Retry on the next tick and count it as "HTF late". A clean run must report 0.
- **D1 merge.** If `TimeToStruct(r.time).day_of_week` is 0 or 6, hold the bar: keep the first open, the maximum high and the minimum low.
  - On the next weekday bar, emit `{time = weekday.time, open = held.open, high = max, low = min, close = weekday.close}`.
  - The merged bar closes at `weekday.time + 86400`. A held bar is never emitted on its own.
  - `Zones.mqh:418-419` already shows that Sunday D1 bars exist for gold.
- **Never use as a level:**
  - `iHigh`/`iLow`/`CopyRates` at shift 0;
  - any time-based read whose last bar is not closure-checked.

  The bar that contains `te` is either partial (tester or live) or already finished (any replay over stored history). Both are wrong. The finished case is the MQL5 equivalent of LuxAlgo SMC's `[0]` + `lookahead_on` leak at line 635.
- **Week boundary.** Get the week start from the calendar, not from `t/604800*604800`, which lands on Thursdays.

**3. Order of events in `OnTick`.** Today the order is: new M1 bar → `ProcessM1`; new entry bar → `SyncH1` → `ProcessBar`; then `PlacePending`; then the simulator. The new order on a tick that opens a new entry bar at `te = iTime(_Symbol, _Period, 0)`:
1. `ProcessM1` for the M1 bar that just closed. It does R4 touches of HTF zones using the current HTF state.
2. `SyncH1`, unchanged (trend filter).
3. `ProcessBar`: group A as before, group B touches and reactions, group C tags. Entries are placed here.
4. **`SyncHtf(te)`**: ingest every HTF bar that closed at or before `te`. Order them by close time, then M15 → H1 → H4 → D1, so that dedup upgrades flow upward. For each ingested bar:
   - apply HTF-close invalidation, MSNR flips and ageing;
   - create new zones with `known = close time`;
   - run dedup;
   - roll PD/PW over.
5. **`ArmCheck`**: using the new bar's open (`iOpen(_Symbol, _Period, 0)`, the first tick's Bid), arm every unarmed HTF zone that is now on the correct side.
6. `PlacePending`.

*Why `SyncHtf` runs after `ProcessBar`.* The entry bar that closed at `te` lies inside the HTF bar that also closed at `te`. So zones born at `te`, and invalidations decided at `te`, must apply only from `te` onward. HTF boundaries are multiples of M5, so no HTF bar closes between two M5 bars.

**4. Zone record and state**

`HtfZone {id, type, dir, top, bottom, tfIdx, bornHtf, known, armed, k0, fired, m1Touched, dead}`

- **Entry-bar processing.** Use the same touch/reaction block as `CSmcZones.OnBar` (`SmcZones.mqh:179-213`), with three differences:
  - skip the zone if it is unarmed or dead;
  - no close-through removal on entry bars;
  - no bar-count expiry on entry bars.

  Consequence: a k0+1 reaction is still possible after k0 closed beyond the far edge, unless the HTF bar itself closed beyond it.
- **On closed HTF bar j of a given tf,** for zones of that tf:
  - FVG, OB, SNR: dead if `close[j]` is beyond the far edge.
  - MSNR: flip. Set `dir = -dir`, `k0 = -1`, `fired = 0`, `m1Touched = false`, `armed = false`; the next `ArmCheck` re-arms it.
  - Age = `j - bornHtf`. Dead if age > 500 (FVG, SNR), > 300 (OB), ≥ 100 (MSNR). These are the same comparisons as `SmcZones.mqh:121-125`.
- **Creation from bar j:**
  - FVG: take `fvg.f[k]` with `i == j`.
  - OB: take `st.OnBar` events with `ev.valid && !ev.initial && ev.ob`.
  - SNR: pivot at `p = j - N`, using the same ≥ left / > right test as `SmcZones.mqh:105-118` with N as a parameter. Bounds: resistance `[max(o,c), h]`, support `[l, min(o,c)]` of bar p.
  - MSNR: the pair `(j-1, j)`, strict colours.
  - `known = B.b[j].t + P`. For a merged D1 bar this is the weekday's time + 86400.
- **Dedup (SNR, MSNR).** When zone Z of tf k is created, look for alive zones with the same type and dir, `tfIdx < k`, and the same price within `_Point/2`. The price is the extreme (`top` for resistance, `bottom` for support) for SNR, and the level for MSNR.
  - Kill those zones and count them as "merged".
  - Z inherits the earliest `k0`, `fired` and `m1Touched`. This keeps a pending k0+1 reaction attached to Z.
- **PD/PW:**
  - When a merged D1 bar closes: kill the old PD pair and create the new one with `known` = that close.
  - At the first entry bar of a new trading week (week key = Monday date of the trading day; a Sunday maps to the next Monday): kill the old PW pair and create the new one from the merged D1 bars of the previous key.
  - Log `iTime(_Symbol, PERIOD_W1, 0)`'s weekday once. At each rollover, compare PW with `iHigh`/`iLow(PERIOD_W1, 1)` and print the mismatch count. Expect 0 if W1 starts on Sunday.
- **"Extreme near the break" log flag.** Find the bar time of the day's high and low among the entry bars already in `g_bars`. Flag it if it is within 15 minutes after a gap of 30 minutes or more, or within 30 minutes before such a gap. Do not hard-code the break time (it moves with US DST).

**5. Group C tag**
- In `CSmcZones.OnBar`, where `k0` is set, and in `OnM1Bar`, where `m1Touched` is set, call `HtfOverlap(dir, top, bottom, d)` with `d = 0.3 * M15.B.b[M15.B.n-1].atr`.
- It returns the first alive, same-dir HTF zone of type FVG, OB, SNR or PD/PW whose interval widened by `d` intersects `[bottom, top]`. It also returns a separate MSNR-overlap flag, which is logged only.
- The state it sees is the pre-sync state, so it only uses zones known at k0's open.
- Store `ovl`, `ovlId`, `ovlTf`, `ovlType` on `SmcZone`.
- At entry time, split each `react[]` mask into two:
  - if any reacting zone has `ovl`, the trade goes to C;
  - otherwise it goes to "A not".

  Group A's own trade is unchanged. C and "A not" are labels on the same orders, not new orders.

**6. Keeping group A byte-identical**
- Only group B adds orders.
- Give B's RC-T draws their own `CRng`, seeded differently. `RctDraw` currently uses `g_rng`: `PhanUngLab.mq5:210`, seeded at `:535`.
- Keep B's arms in a separate array, or accept that the `lenh.csv` RC-T sample indices (`:335`) shift.
- **Regression check:** run with `InpHtf=false` and with `InpHtf=true`. Group A rows of `tong_ket.txt` must match exactly.
- R4 for B zones: add them to the M1 hit list. The R4 watch-cancel rule (an M1 close beyond the far edge) stays as defined.

**7. Warm-up touch state.**
- Build one time-sorted list of HTF warm-up bars.
- First drain the bars that closed before the first entry-TF warm-up bar opens. For zones created there, mark them touched (`k0 = -2`, `fired` = all bits) if any later bar of the zone's own TF has `high >= bottom` (resistance) or `low <= top` (support). A wick touch gives the same answer on any TF, because an HTF high is the maximum of the lower-TF highs.
- Then run the entry-TF warm-up bars through the same loop as live (with `trade=false`), calling `SyncHtf` after each bar. PD/PW rollovers also run during warm-up.
- **Correction (28/09, after review; what `HtfZones.mqh` does now).** Draining "up to the first entry-TF warm-up bar T0" leaves a gap: the part of each HTF bar that contains T0, from its open to T0, is never checked (and a held Sunday D1 bar delays the PW roll). So:
  - Drain only up to a cut where no HTF bar straddles: the latest 00:00 on Tuesday–Saturday at or before T0 (merged D1 bars close there; Sunday and Monday 00:00 are not boundaries because of the Sunday merge).
  - From the cut to T0, feed entry-TF bars to the HTF engine only (a separate bar series; group A untouched) through the live loop: touch/reaction, ingest closed HTF bars (taken from the warm-up arrays, not new date-range requests, which return "no history" across the weekend), PW roll, correct-side check. The last step is the correct-side check at T0 with the open of the first warm-up bar. Touches found there are then marked as warm-up touches (`k0 = -2`).
  - During the drain, touches and the correct-side test use the finest HTF that already has history at that time (M15, then H1, H4, D1; never finer than the zone's own TF). Each such TF switches in on a day cut, so no bar straddles a switch. This catches a zone that becomes correct-side and is touched inside one larger HTF bar. The PW roll in the drain happens on the first bar of the week of that TF.

**8. Self-checks (print at the end; each must be 0 unless noted)**
- Touches, reactions or tags that used a zone with `known > bar open`.
- HTF bars ingested with `open + P > te`.
- "HTF late" count.
- PW vs W1 mismatches (explain if not 0).
- Also print, per TF and type: zones created, merged, dead by HTF close, expired, unarmed at birth, first touches; and warm-up bar counts with first times.

**9. Memory and time**
- Bars: over 9 months, roughly 18k M15, 4.6k H1, 1.2k H4 and 200 D1, plus warm-up. At about 56 bytes per `SmcBar` that is under 2 MB.
- Alive zones: on the order of a few hundred. MSNR dominates at roughly 50 per TF.
- Per entry bar, loop over alive HTF zones only. The M1 run is about 270k bars × a few hundred zones, about 10^8 comparisons, which is acceptable. M5 runs add the same kind of loop per M1 bar for R4.
- Compact dead zones in `SyncHtf` with the keep-index pattern from `SmcZones`, and `ArrayResize` with a reserve.

**10. Pine (only if HTF zones are drawn in `docs/pine/BotVang_SMC.pine`)**
- Copy the method of TFO IFVG, not its code:
  - fetch closed HTF bars with `request.security(syminfo.tickerid, tf, [open[1], high[1], low[1], close[1], time[1]], lookahead = barmerge.lookahead_on)`;
  - detect a new HTF bar with `timeframe.change(tf)`;
  - keep the HTF bars in arrays in the chart script and run the same rules there.
- Never use `lookahead_on` without `[1]`, and never read the forming HTF bar.
- Put a note on the chart: TradingView XAUUSD days usually roll at 17:00 New York, so D1 and H4 zones and PDH/PDL can differ from the Lab.

**Deviations from common indicator practice:** see 25.8. The main ones are:
- SNR zones use the pivot candle's wick part instead of a zero-width line;
- invalidation and flips happen on the zone's own TF close;
- N = 3 on H4 and D1;
- OB comes from the internal layer only;
- the Sunday D1 bar is merged into Monday;
- the armed (correct-side) rule;
- exact-price dedup across TFs;
- PD/PW have first-touch rules;
- the overlap rule is our own, and MSNR is excluded from it.

**Files**
- docs\SPEC.md
- mql5\Include\BotVang\SmcZones.mqh
- mql5\Include\BotVang\SmcDetect.mqh
- mql5\Experts\BotVang\PhanUngLab.mq5
- mql5\Include\BotVang\Zones.mqh
- docs\research\10-tradingview-smc-msnr-ob-fvg.md
- docs\research\05-snr-fvg-ob-algorithms-exness-facts.md
- docs\research\07-exness-execution-tester-slippage.md
- docs\pine\tradingview\fvg\Inverse FVG with Rejections [TFO].pine
- docs\pine\tradingview\msnr\MSnR Classic StoryLine MTF.pine
- docs\pine\tradingview\ob\Smart Money Concepts (SMC) [LuxAlgo] (order block part only).pine
- docs\pine\tradingview\smc\Multi Length Market Structure (BoS + ChoCh).pine
- docs\pine\tradingview\liquidity\Liquidity Swings [LuxAlgo].pine
