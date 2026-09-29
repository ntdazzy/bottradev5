<!-- Tổng hợp nghiên cứu (tiếng Anh) do nhóm đọc tạo ngày 27/09/2026 từ các chỉ báo công khai trên TradingView. Tóm tắt tiếng Việt: docs/HANDOFF.md §0b. -->

# Research synthesis: SMC, MSNR, OB, FVG, liquidity and price-action rules from public TradingView scripts

Sources were read on 2026-09-27. I used public script pages and TradingView's public source viewer (`open_no_auth`). I did not log in or fill in any forms. No Pine code appears below. Every rule is my own paraphrase.

**How far each script was checked (column "Ev" in the index):**
- **D**: I read the full current source in detail.
- **S**: I read the source during discovery.
- **P**: only the page text or a third-party port. Re-read the code before relying on these rules.

**License codes:**
- **NC**: CC BY-NC-SA 4.0, stated in the source header.
- **MPL**: Mozilla Public License 2.0, stated in the header.
- **none**: marked open-source, but the source has no license header. Only TradingView House Rules apply.
- **?**: open-source, header not checked.

Downloaded sources (verbatim, with license headers) are in `docs/pine/tradingview/` (index: `docs/pine/tradingview/README.md`). Several are NC (non-commercial). Project code is written independently from these definitions.

## 0. Script index

| ID | Script | Author | URL | Lic | Ev |
|---|---|---|---|---|---|
| S1 | Smart Money Concepts (SMC) [LuxAlgo] | LuxAlgo | https://www.tradingview.com/script/CnB3fSph-Smart-Money-Concepts-SMC-LuxAlgo/ | NC | D |
| S2 | Market Structure Break & Order Block (MSB-OB) | EmreKb | https://www.tradingview.com/script/DkE7UniD/ | MPL | D |
| S3 | ICT Concepts [LuxAlgo] | LuxAlgo | https://www.tradingview.com/script/ib4uqBJx-ICT-Concepts-LuxAlgo/ | NC | D |
| S4 | Market Structure CHoCH/BOS (Fractal) [LuxAlgo] | LuxAlgo | https://www.tradingview.com/script/ZpHqSrBK-Market-Structure-CHoCH-BOS-Fractal-LuxAlgo/ | NC | D |
| S5 | Smart Money Concepts Probability (Expo) | Zeiierman | https://www.tradingview.com/script/mBINsJlf-Smart-Money-Concepts-Probability-Expo/ | NC | D |
| S6 | SMC Structures and FVG | LudoGH68 | https://www.tradingview.com/script/uJDx1aKO/ | ? | P |
| S7 | Pure Price Action Structures [LuxAlgo] | LuxAlgo | https://www.tradingview.com/script/EuXueiJN-Pure-Price-Action-Structures-LuxAlgo/ | ? (likely NC) | P |
| S8 | Market Structures + ZigZag [TradingFinder] | TFlab | https://www.tradingview.com/script/v2IhxlWK-Market-Structures-ZigZag-TradingFinder-CHoCH-BOS-MSS-MSB/ | ? | P |
| S9 | Multi Length Market Structure (BoS + ChoCh) | Uncle_the_shooter | https://www.tradingview.com/script/Bayq7qtD/ | ? | P |
| S10 | Market Structure (BOS/CHOCH), Advanced & Improved | Confluencer | https://www.tradingview.com/script/0t7puDyH-Market-Structure-BOS-CHOCH-Advanced-Improved/ | ? | P |
| S11 | Market Structure with Inducements & Sweeps [LuxAlgo] | LuxAlgo | https://www.tradingview.com/script/kMDlPZuz-Market-Structure-with-Inducements-Sweeps-LuxAlgo/ | NC | S |
| S12 | Order Block Finder (Experimental) | wugamlo | https://www.tradingview.com/script/R8g2YHdg-Order-Block-Finder-Experimental/ | MPL | D |
| S13 | Order Block Detector [LuxAlgo] | LuxAlgo | https://www.tradingview.com/script/KvGhxGxY-Order-Block-Detector-LuxAlgo/ | NC | D |
| S14 | Order Blocks & Breaker Blocks [LuxAlgo] | LuxAlgo | https://www.tradingview.com/script/piIbWMpY-Order-Blocks-Breaker-Blocks-LuxAlgo/ | NC | D |
| S15 | Volumized Order Blocks, Flux Charts | fluxchart | https://www.tradingview.com/script/bLdpFVuq-Order-Blocks-Flux-Charts/ | MPL | D |
| S16 | Breaker Blocks with Signals [LuxAlgo] | LuxAlgo | https://www.tradingview.com/script/1owp3WD0-Breaker-Blocks-with-Signals-LuxAlgo/ | NC | D |
| S17 | Higher order Orderblocks + Breakerblocks + Range | pmk07 | https://www.tradingview.com/script/zSDlR0YP-Higher-order-Orderblocks-Breakerblocks-Range-Alerts/ | MPL | S |
| S18 | Volume Order Blocks [BigBeluga] | BigBeluga | https://www.tradingview.com/script/5CpArShF-Volume-Order-Blocks-BigBeluga/ | NC | S |
| S19 | Pure Price Action Order & Breaker Blocks [LuxAlgo] | LuxAlgo | https://www.tradingview.com/script/5PB593yX-Pure-Price-Action-Order-Breaker-Blocks-LuxAlgo/ | NC | S |
| S20 | Rejection Blocks [ICT] | filipiti | https://www.tradingview.com/script/klFV2RA5/ | none | S |
| S21 | Fair Value Gap [LuxAlgo] | LuxAlgo | https://www.tradingview.com/script/jWY4Uiez-Fair-Value-Gap-LuxAlgo/ | NC | D |
| S22 | Inversion Fair Value Gaps (IFVG) [LuxAlgo] | LuxAlgo | https://www.tradingview.com/script/8FHucjY6-Inversion-Fair-Value-Gaps-IFVG-LuxAlgo/ | NC | D |
| S23 | Imbalance Detector [LuxAlgo] | LuxAlgo | https://www.tradingview.com/script/C0cC294Q-Imbalance-Detector-LuxAlgo/ | NC | D |
| S24 | Gaps + Imbalances + Wicks (MTF) | LeviathanCapital | https://www.tradingview.com/script/KLiE8iyE-Gaps-Imbalances-Wicks-MTF-By-Leviathan/ | MPL | D |
| S25 | Inverse FVG with Rejections [TFO] | tradeforopp | https://www.tradingview.com/script/arQP5Q2f-Inverse-FVG-with-Rejections-TFO/ | MPL | D |
| S26 | Balanced Price Range (BPR) [TFO] | tradeforopp | https://www.tradingview.com/script/856oabwc-Balanced-Price-Range-BPR/ | MPL | S |
| S27 | Balanced Price Range, Flux Charts | fluxchart | https://www.tradingview.com/script/XA98pxm4-Balanced-Price-Range-Flux-Charts/ | NC | S |
| S28 | FVG Detector [TradingFinder] | TFlab | https://www.tradingview.com/script/7RyvovXb-FVG-Detector-TradingFinder-Fair-Value-Gap-Imbalance-Mitigated/ | MPL | S |
| S29 | ICT - GAPs and Volume Imbalance | Vulnerable_human_x | https://www.tradingview.com/script/MDxlrsRo-ICT-GAPs-and-Volume-Imbalance/ | MPL | S |
| S30 | HTF Fair Value Gap [LuxAlgo] | LuxAlgo | https://www.tradingview.com/script/oOPK4P2K-HTF-Fair-Value-Gap-LuxAlgo/ | NC | S |
| S31 | Inversion Fair Value Gap Signals [AlgoAlpha] | AlgoAlpha | https://www.tradingview.com/script/oi5ABy2g-Inversion-Fair-Value-Gap-Signals-AlgoAlpha/ | MPL | S |
| S32 | MTF FVG | pmk07 | https://www.tradingview.com/script/kG5p9bl4-MTF-FVG/ | MPL | S |
| S33 | MTF Fair Value Gap [BigBeluga] | BigBeluga | https://www.tradingview.com/script/HDA8PAJ8-MTF-Fair-Value-Gap-BigBeluga/ | NC | S |
| S34 | Support and Resistance Levels with Breaks [LuxAlgo] | LuxAlgo | https://www.tradingview.com/script/JDFoWQbL-Support-and-Resistance-Levels-with-Breaks-LuxAlgo/ | NC | D |
| S35 | Support Resistance Channels | LonesomeTheBlue | https://www.tradingview.com/script/Ej53t8Wv-Support-Resistance-Channels/ | MPL | D |
| S36 | Quasimodo Pattern | EmreKb | https://www.tradingview.com/script/SQRSlcup/ | MPL | D |
| S37 | QM Signal [TradingFinder] | TradingFinder (code by chartbox90) | https://www.tradingview.com/script/HuBqQBr5-QM-Signal-TradingFinder-Quasimodo-Pattern-Head-and-Shoulders/ | MPL | D |
| S38 | MSnR Double Breakout Level | RWBTradeLab | https://www.tradingview.com/script/0jssxZUC-MSnR-Double-Breakout-Level/ | none | D |
| S39 | Malaysian SnR [by DanielM] | DanieIM | https://www.tradingview.com/script/yqRdpnSH-Malaysian-SnR-by-DanielM/ | page 404 | P |
| S40 | QML FTB with Quality Score [Malibu] | malibuuu | https://www.tradingview.com/script/4Fv1ooMl/ | MPL | S |
| S41 | MSnR Key Level [6 Types] | RWBTradeLab | https://www.tradingview.com/script/erb7xGg9-MSnR-Key-Level-6-Types/ | none | S |
| S42 | MSnR Fresh & Unfresh Level | RWBTradeLab | https://www.tradingview.com/script/J4VA7UpR-MSnR-Fresh-Unfresh-Level/ | not stated | S |
| S43 | MSnR QM Level | RWBTradeLab | https://www.tradingview.com/script/PdpbKEfY-MSnR-QM-Level/ | not stated | S |
| S44 | MSnR CC Level [6 Types] | RWBTradeLab | https://www.tradingview.com/script/FNzQRXdb-MSnR-CC-Level-6-Types/ | not stated | S |
| S45 | Engulfing Zone [8 Types] | RWBTradeLab | https://www.tradingview.com/script/GJzk9T7E-Engulfing-Zone-8-Types/ | not stated | S |
| S46 | Malaysian SnR and Decision Levels [DoN] (+ Kai: https://www.tradingview.com/script/xg43U6tE/) | DoN_JCT | https://www.tradingview.com/script/iWgxW7bW/ | none | S |
| S47 | MSnR Classic StoryLine MTF | RWBTradeLab | https://www.tradingview.com/script/5ZZmsIHj-MSnR-Classic-StoryLine-MTF/ | none | S |
| S48 | MSNR by kichgds | kichgds | https://www.tradingview.com/script/4RwbQ1ji-msnr-by-kichgds/ | ? | S |
| S49 | Malaysia SNR 2.0 + XAU Scalp Ultimate | okinawan21 | https://www.tradingview.com/script/t49SbqQG/ | ? | S |
| S50 | Liquidity Swings [LuxAlgo] | LuxAlgo | https://www.tradingview.com/script/1S2VOnJP-Liquidity-Swings-LuxAlgo/ | NC | D |
| S51 | Buyside & Sellside Liquidity [LuxAlgo] | LuxAlgo | https://www.tradingview.com/script/Qk4vBbfL-Buyside-Sellside-Liquidity-LuxAlgo/ | NC | D |
| S52 | Liquidity Sweeps [LuxAlgo] | LuxAlgo | https://www.tradingview.com/script/JRqryeJ5-Liquidity-Sweeps-LuxAlgo/ | NC | D |
| S53 | Pure Price Action Liquidity Sweeps [LuxAlgo] | LuxAlgo | https://www.tradingview.com/script/WYB2cYmM-Pure-Price-Action-Liquidity-Sweeps-LuxAlgo/ | NC | S |
| S54 | Liquidity Grabs, Flux Charts | fluxchart | https://www.tradingview.com/script/ZxHyWlMd-Liquidity-Grabs-Flux-Charts/ | MPL | S |
| S55 | Swing Failure Pattern (SFP) [LuxAlgo] | LuxAlgo | https://www.tradingview.com/script/YmWELClV-Swing-Failure-Pattern-SFP-LuxAlgo/ | NC | S |
| S56 | Equal High/Low (EQH/EQL) [AlgoAlpha] | AlgoAlpha | https://www.tradingview.com/script/R53Wm3YL-Equal-High-Low-EQH-EQL-AlgoAlpha/ | MPL | S |
| S57 | Supply and Demand Visible Range [LuxAlgo] | LuxAlgo | https://www.tradingview.com/script/UpWXXsbC-Supply-and-Demand-Visible-Range-LuxAlgo/ | NC | D |
| S58 | Supply and Demand Zones [BigBeluga] | BigBeluga | https://www.tradingview.com/script/I0o8N7VW-Supply-and-Demand-Zones-BigBeluga/ | NC | D |
| S59 | Trendlines with Breaks [LuxAlgo] | LuxAlgo | https://www.tradingview.com/script/IYL88A1N-Trendlines-with-Breaks-LuxAlgo/ | NC | D |
| S60 | Candlestick Patterns Identified (v2 "update 1-17-26") | repo32 | https://www.tradingview.com/script/vcsWo8mh-Candlestick-Patterns-Identified-updated-3-11-15/ | MPL (v2); v1 none | D |
| S61 | Breakout Finder | LonesomeTheBlue | https://www.tradingview.com/script/EvkXjgyw-Breakout-Finder/ | MPL | D |
| S62 | Support Resistance with Breaks and Retests | HoanGhetti | https://www.tradingview.com/script/Xeeko6TV-Support-Resistance-with-Breaks-and-Retests/ | ? | P |
| S63 | Pinbar trailing stop strategy | samgozman | https://www.tradingview.com/script/QtCWpUWb-Pinbar-trailing-stop-strategy/ | none explicit | P |
| S64 | Built-in candlestick patterns (e.g. Engulfing - Bullish) | TradingView | https://www.tradingview.com/support/solutions/43000583771-engulfing-bullish/ | not verified | P |
| S65 | Pivot Reversal Strategy (built-in) | TradingView | https://www.tradingview.com/support/solutions/43000594526-pivot-reversal-strategy/ | not stated | P |
| S66 | InSide Bar Strategy (built-in) | TradingView | https://www.tradingview.com/support/solutions/43000591665-inside-bar-strategy/ | not stated | P |

**Other references:**
- R1: joshyattridge/smart-money-concepts, a Python package under the MIT license. https://github.com/joshyattridge/smart-money-concepts
- R2: LuxAlgo market-structure docs. https://docs.luxalgo.com/docs/luxalgo-toolkits/price-action-concepts/market-structures
- R3: LuxAlgo PineTS PR #322, which documents the Pine pivot tie rule. https://github.com/LuxAlgo/PineTS/pull/322
- Seen but not ranked:
  - robbatt "Smart Money Concepts (Advanced)", a LuxAlgo fork whose live OBs repaint. https://www.tradingview.com/script/srwLDKbR-Smart-Money-Concepts-Advanced/
  - "Strong Weak Highs Lows" by Jos-ProTrader. https://www.tradingview.com/script/lUl81ecq-Strong-Weak-Highs-Lows/
  - "Edo Mitigation Blocks". https://www.tradingview.com/script/ONMiSjzg-Edo-Mitigation-Blocks/

**Discovery summaries that the full source reads corrected:**
- **S1:**
  - The FVG body metric is (close−open)/(open×100).
  - A **bearish FVG is deleted on the first entry into the gap** (high > candle-3 high). A bullish FVG needs a full fill before it is removed.
  - OBs are stored up to 100 per layer and only 5 are shown. Hidden OBs stay live.
  - OB invalidation runs on the creation bar too.
  - A break blocked by a filter uses up that crossover.
- **S2:**
  - The current v9.0 has **no timeframe option** and no request.security.
  - The MSB is wick/zigzag-based, with a guard: a new swing high and a new swing low must both be confirmed between MSBs.
  - "Delete broken boxes" removes the *oldest* box in the list, not the broken one.
- **S15:** drawing is gated on confirmed bars, so zones do **not** flicker intrabar. Merging the display can hide live OBs.
- **S52:** a sweep between the pivot bar and its confirmation is impossible, so the claim that such sweeps are "missed" was wrong.
- **S34:** the license is **CC BY-NC-SA** (not MPL). A level is usable from pivot bar p+16. Alerts do not match labels.
- **S3:**
  - MS length is 5 with 1 right bar. OB lookback is 10. Candle body mode is ON.
  - Liquidity tolerance is 0.4×ATR(10).
  - An FVG requires a displacement middle candle.
  - The IFVG zone is the raw wick overlap; the page text describes it wrongly.
- **S60:** the live v2 has 15 patterns (Dark Cloud Cover removed). The body is measured with abs(). An open[5] trend filter applies to 9 patterns.
- **S12:** the % move uses the absolute value, and threshold 0 means the filter is off.
- **S22:** during warm-up the size threshold has no multiplier.

---

## 1. Taxonomy of definition variants

### 1.1 Market structure (swings, BOS / CHoCH / MSS / MSB)

**Swing source**

| Variant | Exact rule, lag | Used by |
|---|---|---|
| Symmetric pivot Pivot(L=R=N) | high[p] ≥ each of the L left highs and > each of the R right highs (tie rule from R3). Known at bar p+N. | S5 (20), S9 (5/10/15/20), S10, S34 (15), S35 (10), S37 (5), S50 (14), S52 (5), S54 (25), S59 (14), S61 (5) |
| Short right side Pivot(N,1) | Known 1 bar late | S3 (5/1), S16 (5/1), S51 (7/1), S55 (5/1) |
| LuxAlgo "leg" state | Bar t−N counts if its high is above the max of the next N highs. The state alternates, and only the *first* qualifying bar after a flip is kept, which is not always the leg's extreme. Lag N. | S1 (internal 5, swing 50, EQ 3), S11 (50 / IDM 3), S14 (10), S15 (10), S3 OB layer (10) |
| Strict monotonic fractal | p = floor(len/2) strictly rising bars before the centre and strictly falling bars after it. Equal highs never qualify. Only one live level per side. | S4 (len 5) |
| Recursive 3-bar fractals (short, intermediate, long term) | Ties allowed. Lag varies. | S7, S19 (intermediate), S53 (long) |
| Donchian-flag zigzag | A new N-bar high or low flips the trend. The extreme of the leg is stored at the flip; the window skips 2 bars after the last opposite flag. | S2 (9), S36 (13), S40 (13) |
| Close / body pivots | Pivot of the close series (a line-chart peak) or of the body edges | S46 (close 3/3), S48 (body 10/2), S35 option |
| Second-order pivots | A pivot of 3-bar fractals | S17 |
| Running level reset at pivots | Up = highest high since the last confirmed 20/20 pivot high | S5 |

**Break confirmation**
- **Close strictly beyond the level, once per swing:** S1, S3, S4, S9, S11, S14, S15, S19, S59 (against a sloped line).
- **Wick beyond the level:** S5 (all events), S37 (pivot value), S10 (option).
- **Mixed:** BOS needs a close and CHoCH accepts a wick in S8. S10 has a close/wick switch.
- **Zigzag comparison with extension:** in S2, h0 > h1 + 0.33×|h1−l0|, checked only at zigzag flips, so the MSB is known late. S36 uses h0 > h1 plus close > l1.
- **BOS only after an inducement (IDM) sweep:** S11.
- **S1 internal filters:** an optional wick-shape "confluence" filter (it has an operator-precedence quirk), and the internal level must differ from the swing level.

**Labels**
- **CHoCH and BOS:** CHoCH is the first break against the last break direction; BOS is a break in the same direction. The first break ever is a BOS. Used by S1, S3 (MSS/BOS, with BOS de-duplicated by price), S4, S9, S10.
- **Three states:** CHoCH, then SMS (the first continuation after about resp−1 flat bars), then BMS for later continuations. Used by S5.
- **MSB flip only:** S2.
- **CHoCH+:** a CHoCH preceded by a failed HH or LL, with BOS allowed only after a CHoCH. Used by S7 and R2.

**Context**
- **Premium/discount:**
  - S1: premium = top 5% of the trailing swing range, equilibrium 47.5–52.5%, discount = bottom 5%.
  - S5: bands at 10–25% and equilibrium at 45–55% of the Up–Dn range.
  - S6: Fibonacci levels 0.382–0.786 (OTE area).
  - S16: E must sit below 50% of the range.
- **Strong/weak high and low:** S1.
- **Statistics of the next structure event:** S5.

### 1.2 Order blocks, breakers, mitigation and rejection blocks

**How the OB candle is chosen**

| Variant | Rule | Used by |
|---|---|---|
| (a) Extreme candle strictly between the swing and the break bar | For a bullish OB, the lowest low (or lowest body bottom) in the bars strictly between the swing bar and the break bar. Ties go to the oldest bar. | S14, S15 (rejected if range > 3.5×ATR10), S19 (body), S3 (body, both ends excluded) |
| (a') Same, but the pivot bar is included | Volatile bars (range ≥ 2×ATR200) get high and low swapped, so they are rarely picked | S1 |
| (b) Last opposite candle before P same-colour candles | P = 5. A % move filter uses the absolute value; default 0. | S12 |
| (c) Last opposite-colour candle of the leg into the MSB | Also: the last same-colour candle at the old swing becomes a breaker (BB) or mitigation block (MB) | S2 |
| (d) Volume-pivot candle | Largest volume within ±5 bars. Direction comes from a one-sided swing state. The zone is half the candle. | S13 |
| (e) Two-candle zone at a higher-order swing | Created when an MSB is confirmed by a first-order pivot | S17 |
| (f) Extreme of the last 18 bars on an EMA(5)/EMA(18) cross | Minimum height = highest ATR200 over the last 200 bars | S18 |
| (g) ICT breaker | A–E swings. Needs a sweep (E < C) and a close > D. The zone is the first up candle found scanning from D back to C. | S16 |
| (h) Rejection block | The long wick of a Pivot(3,3) candle, with wick ≥ 2×body | S20 |
| (i) Base candle before a 3-candle run with high volume | See supply and demand | S58 |

**Zone edges**
- Full wick: S1, S2, S14, S15, S16.
- Body: S3, S19, and an option in S14 and S16.
- Low to open: S12.
- Low to (high+low)/2: S13.
- Base extreme ± 2×ATR200: S58.
- Wick tip to body: S20.

**Invalidation**
- Wick through the far edge: S1 default, S13 default, S15 default.
- Body through the far edge, i.e. min/max(open, close): S14, S19, and S15 "Close" mode.
- Close through the far edge: S1 and S13 options, S18, S20, S58.
- Judged by pivots: S17.
- None: S12.

**After invalidation**
- Deleted: S1, S13, S18, S20, S58.
- Becomes a breaker:
  - S14 and S19 flip on the body and remove the breaker on a close through the other edge.
  - S15 flips on the wick and removes on a wick through the other edge.
  - S17 uses pivots.

**Entry or touch rules actually coded**
- **S16:** long when the bar opens between the midline and the top and closes above the top. Cancel on a close between the bottom and the midline. The zone ends on a close below the bottom. Take-profits at top + 2, 3 and 4 zone heights.
- **S20:** first retest where low ≤ top and close ≥ bottom.
- **S2:** alert on every bar that closes inside the zone.
- **S58:** a bar straddling the near edge marks the zone "tested".
- All other OB scripts only draw zones and define no entry.

**Mitigation block:** no popular open script. The LuxAlgo concept is a breaker without the sweep. S2 labels it Bu-MB or Be-MB when the prior extreme was not swept.

### 1.3 FVG, IFVG, BPR, volume imbalance, opening gap

**Core rule (shared by all):** a bullish FVG exists when low3 > high1, with zone [high1, low3]. A bearish FVG exists when high3 < low1, with zone [high3, low1]. The FVG is known only at the close of candle 3. CE is the midpoint.

**Condition on the middle candle**
- None: S24, S26, S32, and S28 in base mode.
- close2 beyond candle 1's extreme: S1, S21, S22, S23.
- Candle 2 spans the whole gap: S25, S29.
- Displacement candle (body > SMA5 of bodies, each wick < 36% of body): S3.
- Direction taken from candle 2's colour: S25, S27.
- ATR(55) presets, e.g. "Defensive" = candle-2 range ≥ 1.5×ATR55 plus colour/body tests: S28.
- Candle-2 body fraction > 2× its running mean: S1 auto mode.

**Size filter**
- None: S21 default, S26, S29, S32.
- % of price: S21 manual.
- Mean bar range %: S21 "Auto". The page wrongly says it averages FVG heights.
- 0.25×ATR200: S22.
- 0.3×ATR150: S31.
- 0.3 × (sum of 21 ranges / 20): S25.
- 0.16×ATR20 plus middle body > 0.3×(body1 + body3): S27.
- 1.0×ATR30 or 0.30%: S24.
- Optional minimum width in points, % or ATR200: S23.

**Excluding gap bars**
- Drop the FVG if an opening gap happened on this bar or the previous one: S23.
- Drop the FVG if any open-to-previous-close gap is > 0.5×ATR20: S27.

**Consecutive FVGs in the same direction**
- Replace the newest record: S3.
- Merge into a "liquidity void": S29.
- Keep separate: all others.

**Touch and mitigation, from loosest to strictest**
1. First wick touch of the near edge: S28 (= mitigated), S29 "Mitigate", S3 "entered", S24 "Touch" (the bar must strictly straddle an edge).
2. CE reached: S24 "Half", S33 "Avg".
3. Wick through the far edge: S3, S23 (statistics only), S32, S1 for bullish FVGs.
4. Body through the far edge: S22, S27.
5. Close through the far edge: S21, S25, S31, S29 "Engulf".
- Also: S1's bearish FVG is deleted on first entry. "Rebalance" shrinks the zone to its unfilled part in S32 and S29. Zones expire after 1000 bars in S31 and after 200 untouched bars in S27.

**IFVG**
- **Inversion** by body (S22, S27) or by close (S25, S31, S29).
- **IFVG death:**
  - Body back through: S22.
  - Close back through: S25, S31.
  - Wick: S27.
- **Signals:**
  - S22: previous close inside the zone and current close outside ("Close" mode), or the bar's wick inside and its close outside ("Wick" mode).
  - S25: a chart pivot inside the zone. The code ignores the zone's direction.
  - S31: close inside, later close back out.
  - S27: wick in, close out.

**BPR (three definitions that do not agree)**
- S26: the intersection of opposite FVGs formed within 10 bars. It appears one bar late and dies on a wick.
- S3: built from the newest bull FVG and newest bear FVG. The direction comes from which FVG is higher, and filled FVGs can be used.
- S27: a new FVG overlapping an active opposite IFVG. The zone is the new FVG's own bounds.

**Volume imbalance (VI)**
- S23 and S3, effective rule: high[1] < body bottom of the current bar, and low < high[1]. The zone runs from the previous body top to the current body bottom.
- S29 "Classic": open > previous close, low ≤ previous high, both candles bullish. The zone runs from the previous close to the open.

**Opening gap (OG)**
- S23: low > high[1]. The zone uses body edges.
- S29 "True GAP": the wick gap.
- S24 "Gap": a 2-candle gap.

**Implied FVG:** S3 (the code uses the wick overlap), S29 (between wick midpoints).

**Higher timeframe (HTF)**
- S1: lookahead_on reading the current HTF bar. This is a **future leak**.
- S21, S24, S30: request.security with lookahead off on the *forming* HTF bar, so real-time zones repaint.
- S25: offset [1] with lookahead_on. This is correct.
- S32: confirmed HTF bars only. This is correct.
- S33: draws HTF boxes with chart-timeframe highs and lows. This is a bug.

### 1.4 MSNR / SNR

- **Source of A and V levels:**
  - A candle-colour pair priced at the *first candle's close*. A = green then red, V = red then green. Used by S38, S41–S44, S47, S39 (page text), and the Milana page.
  - A close-series pivot with 3 bars each side (a line-chart peak or valley): S46. The trading-guide page uses the same "line chart" wording.
  - A body pivot with 10 left and 2 right bars, on H1/H4/D: S48.
  - On a gapless feed the colour-pair rule is roughly a close pivot with N=1.
- **Gap levels:**
  - Two same-colour candles, priced at the first candle's close: S39, S41, S42.
  - Priced at the second H4 candle's open ("Decision level"): S46.
- **Fresh vs unfresh:**
  - Fresh means no wick touch since creation or since the last flip.
  - S42 exact rule: a touch means high ≥ level − ½ tick with the close back on the original side. A close through the level flips it and makes it fresh again. The breakout check runs before the touch check.
  - S48 uses "unfresh" to mean *broken*.
- **Flip (SBR/RBS):**
  - Close through the level: S42.
  - Close through the level with the candle's colour agreeing: S41.
  - After a flip, the history line is deleted when price closes back through it: S46.
- **Lifetime / density:** 20 bars in S42, 25 in S41, 50 in S43 and S44, 200 in S38 and S45, 5 active levels per side in S46.
- **QM / QML:**
  - S36: Donchian zigzag 13. Bullish when h2 > h1, l0 < l1, h0 > h1 and close > l1. QML = l1. The signal re-fires on close re-crosses.
  - S37: pivot 5 with HH/LH/HL/LL labels and a wick-based CHoCH. Entry at the left shoulder, SL at the head ± ATR21/2, TP1 at the broken swing, TP2 at the newest swing.
  - S43: close-based A/V version.
  - S40: first touch back (FTB) plus filters. The source defaults differ from the page.
- **Other constructs:**
  - DBO (double breakout staircase): S38.
  - Confirmation-candle levels, where a doji counts as green: S44.
  - Engulf, meaning the confirming candle *closes* beyond the base candle's high or low; ER and T1 sweep variants: S45.
  - Storyline: S47 (an HTF fresh-level rejection, then an LTF close beyond the locked A/V level); Milana (price vs the W/D open); S46 HTF overlay.
  - Objective zone layers: S34 (pivot level plus a tick-volume break filter) and S35 (pivot clusters ranked by strength).

### 1.5 Liquidity (pools, EQH/EQL, sweeps)

- **Level source:**
  - Pivot(N,N): S52 (5), S50 (14; the zone is the wick part or the full range), S54 (25).
  - Pivot(N,1): S51 (7 with a zigzag), S55 (5, latest level only).
  - Recursive fractal: S53.
  - The running max since the CHoCH: S11.
- **Equal highs and lows:**
  - At least 3 zigzag pivots within ±0.69×ATR10: S51.
  - At least 3 within ±0.4×ATR10: S3.
  - 2 consecutive EQ pivots (N=3) within 0.1×ATR200: S1.
  - Two *adjacent candles* within 0.05×EMA500 of the average high/low change, plus an RSI filter: S56. Turning the filter off produces no zones (bug).
- **Sweep definition:**
  - Wick through the level and close back: S52 "Only Wicks", S53, S11.
  - The whole body stays on the original side and wick/body ≥ 0.5: S54.
  - Open and close both inside, then a confirming close beyond the lowest low between the swing and the SFP bar: S55. Unconfirmed SFPs are deleted from the chart.
  - The high goes beyond mid + 0.69×ATR, with no close condition: S51.
  - Close through the level, then a later wick back with a close on the breakout side ("outbreak & retest"): S52.
  - A close means "taken": S3.
- **After the sweep:**
  - A sweep box [level, wick extreme] that dies on a close beyond the wick: S52.
  - A breach zone of ±2.3×ATR10 that lasts until price leaves it: S51.
  - The SFP dies on a close beyond the swing or after 500 bars: S55.
- **Touch counting:** S50 counts overlapping bars with a 14-bar lag, and the count is inflated by the pivot's own right-side bars.
- **Liquidity voids:** 3-bar gaps larger than ATR200, split into 13 slices: S51.

### 1.6 Supply and demand

- **S58:**
  - Three same-colour candles. The middle one needs volume above the 1000-bar average.
  - The base is the nearest opposite candle 3–5 bars back.
  - The zone is a fixed 2×ATR200 box hanging from the base candle's low (supply) or high (demand).
  - Cooldown of 14 bars per side.
  - Touch = a bar straddling the near edge. Invalidation = close beyond the far edge. On overlap, the farther zone is deleted.
- **S57:** volume shelves at the top and bottom of the *visible chart range*, holding 10% of volume across 50 bins. It repaints by design; for a bot, replace the visible range with a rolling window of N closed bars.
- **S35:** pivots clustered into channels up to 5% of the 300-bar range wide. Strength = 20 × pivots + touches.
- **Related:** the "base" order-block definitions in S12 and S18.

### 1.7 Price-action patterns and breakouts

- **Candlestick dictionary S60:**
  - v2 applies an open[5] trend filter to 9 of its 15 patterns and uses abs(body). v1 has no filter and uses a signed body, which makes green hammers looser.
  - Engulfing compares bodies only.
  - Stars do not check candle sizes.
  - Gap tests compare against the previous close. These are fragile on continuous feeds.
- **Built-in definitions S64:**
  - Average body = EMA14 of body. A wick counts only if it is > 5% of the body. Doji = body ≤ 5% of range. A "dominant" wick is ≥ 2×body.
  - The trend filter is close vs SMA50.
- **Pin bar S63:** open and close both in the top 30% of the range, and low < previous low.
- **Inside bar S66:** high < previous high and low > previous low.
- **Pivot Reversal S65:** stop orders 1 tick beyond the last confirmed 4/2 pivot. Always in the market.
- **Breakouts:**
  - S34: a close cross of the 15/15 pivot level plus a tick-volume oscillator > 20.
  - S59: an ATR-sloped ray from the latest 14/14 pivot. mult = 0 gives a close-BOS.
  - S61: a multi-tested level. It really requires at least mintest+1 pivots below the close.
  - S62: break then retest, with a "candle confirmation" non-repainting mode.
- **Displacement candle:** S3 (body > SMA5 of bodies, both wicks < 36% of body).

---

## 2. Canonical definitions (exact, closed-bar, no look-ahead)

Items marked "(ours)" are our own choices, not taken from any script. Everything else follows the cited script's behaviour.

### 2.0 Shared conventions (C0)
1. **Bar loop.** Run once per new chart-timeframe bar. Let i be the just-closed bar (MQL5 shift 1). Rules read bars ≤ i only.
   - Each object stores t_origin (for drawing only) and t_known = close time of bar i.
   - An object can be touched or traded only from the first tick after t_known.
2. **Prices and fills.**
   - Bars are Exness Bid OHLC. Bar-state rules use Bid bars.
   - Tick fills:
     - buy limit when Ask ≤ P; sell limit when Bid ≥ P;
     - buy stop when Ask ≥ P; sell stop when Bid ≤ P;
     - long SL when Bid ≤ SL; short SL when Ask ≥ SL.
   - Close-based states are decided only at bar close, never intrabar.
3. **Candle colour.** Green: c > o. Red: c < o. Doji: c == o after NormalizeDouble(_Digits).
4. **ATR.** Wilder RMA of true range, length 14, seeded with the SMA of the first 14 true ranges.
   - MT5's iATR is a plain average of true range, so compute the RMA manually.
   - A zone's buffers use ATR frozen at its creation bar.
5. **Pivot(L,R).** Bar p is a pivot high, known at bar p+R, if high[p] ≥ high[p−k] for k = 1..L and high[p] > high[p+k] for k = 1..R. Pivot lows are the mirror. This matches Pine per R3; confirm on a chart.
6. **Swing zigzag.** Take confirmed pivots in bar order.
   - A pivot of the same type as the last swing replaces it only if it is more extreme; otherwise it is dropped.
   - If one bar gives both a high and a low, process first the type opposite to the last swing.
7. **Warm-up.** Ignore events before bar max(300, 2 × the longest lookback). Use a fixed start date per test.
8. **HTF.** Use closed HTF bars only. An HTF object is known from the first chart tick after its HTF bar closes.
9. **Gap bar.** Flag bar k when |open[k] − close[k−1]| > 0.5×ATR. This matters for the XAUUSD daily break and weekend.
10. **Event log.** Each object keeps an id, type, direction, layer, bounds, t_origin, t_known, and every state change with its bar and tick time.
    - The Pine indicator uses the same rules on barstate.isconfirmed and keeps history (it does not redraw only on the last bar).
    - It marks t_known on every object.

### 2.1 Market structure: MS-1 (two independent layers)
- **Swings.** C0 zigzag with Pivot(N,N). Defaults: internal layer N = 5, swing layer N = 20 (ours).
  - N = 50 is the LuxAlgo-parity variant.
- **References.** H = the latest swing high in the zigzag (price, bar p_H, broken = false). L is the mirror. When a new swing high replaces H, broken resets.
- **Bullish break at bar i.**
  - Condition: close[i] > H.price (strict) and H.broken == false.
  - Set H.broken = true.
  - Label: **CHoCH** if the trend state T == −1, otherwise **BOS**. When T == 0, label it BOS-initial and exclude it from statistics.
  - Set T = +1.
- **Bearish break:** the mirror (close[i] < L.price).
- **Protected low PL** = the lowest low of bars p_H+1..i. **Dealing range** = [PL, the highest high since p_H], updated as it trails.
  - Premium is above 50% of the range, discount below 50%.
  - OTE is the 0.62–0.79 retracement.
- **Flags stored per break:**
  - Break-candle body in ATR units.
  - Whether the break candle is a PA-1 displacement candle.
  - CHoCH+ (for a bullish CHoCH, the latest swing low is above the previous swing low).
  - Bars between pivot confirmation and the break.
- **Variants to measure:**
  - Wick break (S5).
  - Close plus a 0.1×ATR buffer.
  - The S8 mix (BOS by close, CHoCH by wick).
  - LuxAlgo leg pivots 5/50 (S1).
  - The strict fractal, len 5 (S4).
  - The S2 zigzag 9 with the 0.33 extension.
  - The S3 zigzag with 5 left and 1 right bar.
  - Multi-length 5/10/15/20 (S9).
  - IDM-gated BOS (S11).
  - The CHoCH/SMS/BMS state machine with prd 20, resp 7 (S5).
  - Premium/discount at 95/5 (S1).

### 2.2 Order block OB-1 and breaker BRK-1
- **Creation.** On each MS-1 break (per layer) at bar i that breaks the swing high at p_H:
  - Window W = bars p_H+1..i−1.
  - k* = the bar in W with the lowest low (ties go to the earliest bar). If W is empty, there is no OB.
  - Reject the OB if range(k*) > 3.5×ATR (from S15). Log the rejection.
- **Zone** = [low(k*), high(k*)], with mid = the average. t_known = close of bar i.
- **States, checked each closed bar j > i:**
  - **TOUCHED:** the first j with low[j] ≤ top. Record the exact tick time. Also count "re-entries": a bar with low ≤ top after a bar that closed above the top.
  - **INVALIDATED:** the first close[j] < bottom. This spawns a BRK-1.
  - **EXPIRED:** after 300 bars (ours; statistics only).
- **Bearish OB:** the mirror (highest high in W; invalidated when close > top).
- **Variants:**
  - Window includes the pivot bar, with the volatile-bar swap (S1).
  - Body zone (S3, S19).
  - Last opposite-colour candle of the leg (S2, the textbook definition).
  - Last opposite candle before 5 same-colour candles (S12).
  - Volume-pivot OB (S13).
  - Invalidation by wick (S1, S13, S15) or by body (S14, S19).
  - Internal vs swing layer.
  - OB after CHoCH vs after BOS.
- **BRK-1.** When a bullish OB is invalidated at bar j, create a bearish breaker [bottom, top] with t_known = close of j.
  - TOUCHED: the first high ≥ bottom.
  - DEAD: the first close > top. Expires after 300 bars.
  - Variants: flip on body < bottom (S14); the ICT breaker that needs a sweep E < C, with the S16 signal and cancel rules; the mitigation-block label when there was no sweep (S2).

### 2.3 Imbalances
- **FVG-1 (bullish, at bar i).**
  - Conditions:
    - low[i] > high[i−2];
    - close[i−1] > high[i−2] (S21/S22/S23);
    - gap > 0.25×ATR (the ratio from S22, applied to ATR14);
    - neither bar i−1 nor bar i is a gap bar (from S27).
  - Zone [high[i−2], low[i]], CE = the midpoint. t_known = close of bar i.
  - States from bar i+1:
    - TOUCHED: low ≤ top.
    - CE_HIT: low ≤ CE.
    - FULL_FILL: low ≤ bottom (statistics only).
    - **INVALIDATED:** close < bottom. This creates an IFVG.
  - Each FVG is its own record. Expiry after 500 bars (ours).
  - Bearish is the mirror.
  - Variants:
    - no middle-candle filter (S24, S26, S32);
    - candle 2 spans the gap (S25, S29);
    - displacement middle candle (S3);
    - TradingFinder presets (S28);
    - size 0, 0.1 or 0.5×ATR;
    - invalidation by wick (S3, S32) or by body (S22, S27);
    - CE and rebalance models (S24, S32);
    - merging consecutive FVGs (S29).
- **IFVG-1.** A bullish FVG invalidated at bar j becomes a bearish IFVG [bottom, top] with t_known = close of j.
  - Retest: the first high ≥ bottom.
  - DEAD: close > top. Expires after 200 bars (ours).
  - Variants: body-based inversion and death (S22, S27); the S22 close/wick signal; pivot rejection inside the zone that matches the zone's side (S25, fixed).
- **BPR-1 (from S26).** At the bar that completes a bullish FVG, if a bearish FVG completed ≤ 10 bars earlier:
  - zone = [max(bottoms), min(tops)], and it needs top > bottom;
  - t_known = close of that bar (S26 adds one bar of delay; that is a variant);
  - dies on a close < bottom (S26 uses a wick).
  - Variants: the S3 and S27 definitions.
- **VI-1 (S23 effective rule).** Bullish when high[i−1] < min(open, close)[i] and low[i] < high[i−1]. Zone = [max(open, close)[i−1], min(open, close)[i]].
- **OG-1.** Bullish when low[i] > high[i−1]. Zone = the wick gap [high[i−1], low[i]]. The body-edge version from S23 is a variant.

### 2.4 MSNR
- **LV-1 levels (S41/S42 rules).**
  - At the close of bar i, look at the pair (i−1, i):
    - green, red → A (resistance);
    - red, green → V (support);
    - green, green → BullGap (support);
    - red, red → BearGap (resistance).
  - Price = close[i−1]. Testing starts at bar i+1.
  - Default set: A and V only. Lifetime 100 bars (ours; S42/S41/S38 use 20/25/200).
  - Variants:
    - include gap levels;
    - gap priced at open[i] (S46);
    - A/V from a close-series pivot with N = 3 (S46), which gives far fewer levels;
    - lifetimes of 20, 50 and 200 bars.
- **FU-1 state (S42 order), for each bar j:**
  1. A resistance-side level with close[j] > level flips to support (RBS) and is FRESH. Support-side levels mirror this (SBR).
  2. Otherwise, if high[j] ≥ level (resistance) and the close stays below it, the level becomes UNFRESH and its touch count increases.
  - Variants: the flip needs the breaking candle's colour (S41); tolerance of 0.05×ATR or the spread.
- **QM-1 (bullish).**
  - The zigzag (N = 5) must end with swings in this order: H_a, L_ls, H_b, L_head.
  - Conditions: H_a > H_b (a lower high), L_head < L_ls (a lower low), and H_b not yet broken.
  - Trigger: the first close[i] > H_b. **QML = L_ls.**
  - The setup ends when price fills QML, closes below L_head, or 50 bars pass.
  - Variants: S36 (with re-fires removed), S37, S43, S40.
- **DBO-1:** the S38 staircase rules exactly as written: close-only breakouts, strict slide/restart logic, level = A2 or V2, usable from confirmBar.
- **HTF bias:** T of the MS-1 swing layer on closed H4 bars (ours). Variants: the S47 storyline procedure; price above/below the weekly or daily open.

### 2.5 Liquidity
- **LQ-1:** confirmed Pivot(5,5) highs are buy-side liquidity and lows are sell-side. Active from p+5.
  - BROKEN at the first close beyond the level. Expires at 500 bars (S52 uses 2000).
- **EQ-1:** two consecutive same-type swings in the Pivot(3,3) zigzag with |Δ| ≤ 0.1×ATR14 (the ratio from S1).
  - EQH level = the higher of the two. Known when the second swing is confirmed.
  - Variants: ≥ 3 swings within 0.4×ATR (S3) or 0.69×ATR (S51).
- **SW-1 (sweep of a buy-side level L).**
  - Bar j with high[j] > L and close[j] < L, where L is not broken and not already swept.
  - Record the depth (high − L) in ATR units and the wick-to-body ratio.
  - After a sweep, L can never be swept again. It dies on a close > L.
  - Variants:
    - whole body stays below L, with wick/body ≥ 0.5 (S54);
    - open and close both below L plus the S55 confirmation;
    - minimum depth of 0.1×ATR or the spread;
    - the S51 breach threshold;
    - the S52 outbreak & retest.

### 2.6 Supply and demand: SD-1 (ours, a displacement-origin OB)
- **Supply at bar i:**
  - Bars i−2..i are all red (a doji breaks the run).
  - Net move open[i−2] − close[i] ≥ 1.5×ATR.
  - Base = the nearest green candle among bars i−3..i−5.
- **Zone** = the base candle's full range.
- **Touch:** high ≥ bottom. **Invalidation:** close > top.
- **Demand:** the mirror.
- **Measure it against OB-1.** Variants:
  - S58: the middle bar's tick volume > SMA1000 of tick volume; a fixed 2×ATR200 box; 14-bar cooldown.
  - S12: 5 follow-through candles.
  - S57 on a rolling window: 200 closed bars, 10%, 50 bins.
  - S35 channels as an objective S/R layer.

### 2.7 Price action: PA-1
- **Definitions:** body = |c−o|, range = h−l, uw = upper wick, lw = lower wick.
- **Displacement candle (S3):** body > SMA5(body) including the current bar, and uw < 0.36×body and lw < 0.36×body. Variant: body ≥ 1×ATR.
- **Bullish engulfing (bodies only):**
  - previous candle red and current candle green;
  - close ≥ previous open and open ≤ previous close, with at least one of the two strict;
  - current body > previous body.
  - Variant: the S64 small-body/long-body test against EMA14 of the body.
- **Bullish pin bar (S63):** min(o, c) ≥ h − 0.3×range, and l < l[1]. Variant: without the sweep of the previous low.
- **Inside bar:** h < h[1] and l > l[1].
- **No trend filter.** Context comes from zones and structure.

---

## 3. Testable hypotheses

### 3.0 Protocol (applies to all)
- **Data.** 9 months of Exness real ticks for XAUUSD, BTCUSD and ETHUSD. Bars are built from Bid on M5, M15 and H1, with H4 used for bias.
- **Split.** Months 1–6 for discovery; months 7–9 are a hold-out that is only opened for variants chosen on the discovery months. Alternatively, run a monthly walk-forward.
- **Costs.** Real spread from ticks plus commission. Limit orders get no slippage; stop orders get a measured slippage.
- **Metrics per cell (symbol × timeframe × layer × variant):**
  - number of trades, fill rate, time to fill;
  - win rate, E[R] after costs, profit factor, max drawdown in R;
  - MFE and MAE in ATR units, time in trade;
  - breakdown by session hour (UTC).
- **Random controls:**
  - **RC-L (random level)**, for zone-return setups.
    - At each real setup's t_known, place a synthetic zone in the same direction.
    - Its distance from the close and its height are resampled from the real setups of that cell.
    - Apply the same order, cancel, SL and TP rules. Use 20 replicates with a fixed seed.
    - This tests whether the zone's *location* matters, compared with any limit order at a typical pullback distance.
  - **RC-T (random time)**, for event setups. Random bars matched on symbol, timeframe, UTC hour and ATR decile, with the same share of directions, the same SL distance in ATR and the same R target.
  - **RC-D (direction flip).** The same entries with the opposite direction and mirrored SL/TP. This checks whether the result is just cost drag.
  - **RC-X (ablation).** The same setup with one ingredient removed.
- **Pass rule:**
  - E[R] of the signal minus E[R] of the control > 0 after costs, with a bootstrap 95% CI that excludes 0 on the discovery months;
  - the same sign on the hold-out;
  - on at least 2 of the 3 symbols;
  - flag cells with fewer than 100 trades;
  - count every variant tried, and correct for multiple testing (Bonferroni, or decide on the hold-out only).

### 3.1 Hypotheses

**H0 – Structure baseline (run this first; it places no trades).**
For each MS-1 event (layer × BOS/CHoCH × direction), measure:
- P(next event is a continuation);
- MFE and MAE in ATR at 10, 20 and 50 bars;
- the lag from pivot to break.

Compare against RC-T bars. This is S5's idea done properly: use R/(R+C) over resolved events only, and report the sample size.

**H1 – First return to an unmitigated FVG created by the break (continuation).**
- **Setup.** An MS-1 bullish BOS or CHoCH at bar i. Take the most recent bullish FVG-1 whose candle 2 lies in bars PL+1..i (so it completes by i+1). It must still be FRESH at t_known = max(break close, FVG close).
- **Entry.** Buy limit at the FVG top. Variants: at the CE; at the bottom.
- **Stop.** FVG bottom − 0.1×ATR. Variant: PL − 0.1×ATR.
- **Target.** 2R. Variants: 1R and 3R; the break-leg high; the next buy-side LQ-1 level.
- **Cancel before fill:**
  - 30 bars pass (variants 10 and 100);
  - a close below the FVG bottom;
  - price reaches the target price first (it ran away without us);
  - an opposite MS-1 break on the same layer.
- **Controls:**
  - RC-L.
  - RC-X1: the same rules on FVGs with no linked break (tests the value of the BOS).
  - RC-X2: the same breaks with no FVG, entering with a limit at 50% of the break leg (tests the FVG's location).
  - RC-D.

**H2 – OB retest after a CHoCH (reversal).**
- **Setup.** An MS-1 bullish CHoCH, which gives an OB-1. Variants: require CHoCH+; require a displacement break candle.
- **Entry.** Buy limit at the OB top (variant: at the midpoint).
- **Stop.** OB bottom − 0.1×ATR.
- **Target.** 2R. Variants: the CHoCH leg high; the nearest buy-side level.
- **Cancel.** 50 bars; a close below the bottom; target reached first; a new bearish break.
- **Controls.** RC-L; RC-D; and H3 as the ablation.

**H3 – OB retest after a BOS (continuation).**
- Same geometry as H2.
- Variant: only take an internal-layer OB when the swing-layer trend T agrees.
- Compare H2 vs H3 vs RC-L.

**H4 – Liquidity sweep and reclaim.**
- **Setup.** An SW-1 bullish sweep of a sell-side LQ-1 level at bar j. Variants: an EQ-1 EQL; the body variant of SW-1; a minimum depth of 0.1×ATR.
- **Entry.** Market at the open of bar j+1. Variants: a buy stop at high[j], valid for 3 bars; the S55-style confirming close.
- **Stop.** low[j] − 0.1×ATR.
- **Target.** 2R. Variants: 1R; the nearest unswept buy-side level.
- **Controls:**
  - RC-T.
  - RC-X: bars with the same candle shape (wick below the previous low, close back above it) that are *not* at a level. This tests whether the level matters.
  - RC-D.

**H5 – Sweep, then CHoCH, then FVG or OB entry (ICT model).**
- **Setup.** An SW-1 bullish sweep, followed within 20 bars by an internal-layer bullish CHoCH. The entry zone is the FVG-1 in the CHoCH leg, or the OB-1 if there is no FVG.
- **Entry.** Buy limit at the zone top.
- **Stop.** Sweep low − 0.1×ATR.
- **Target.** The nearest buy-side level. Variant: 3R.
- **Controls.** RC-X: the same CHoCH-plus-zone entries with no prior sweep. RC-L.

**H6 – Breaker retest.**
- **Setup.** A BRK-1 bearish breaker.
- **Entry.** Sell limit at the breaker bottom.
- **Stop.** Breaker top + 0.1×ATR.
- **Target.** 2R.
- **S16-exact variant.** Enter at the close of the signal bar. Cancel on a close back through the midline. Take profits at 2, 3 and 4 zone heights.
- **Controls.** RC-L; RC-X: the original OB touches.

**H7 – IFVG retest.**
- **Setup.** An IFVG-1 bearish zone.
- **Entry.** Sell limit at the zone bottom.
- **Stop.** Zone top + 0.1×ATR.
- **Target.** 2R.
- **Cancel.** 50 bars, or a close above the top.
- **Variant.** The S22 close-mode signal, entering at the next open.
- **Controls.** RC-L; RC-X: a retest of the IFVG's CE instead of its edge.

**H8 – First touch of a fresh MSNR level (rejection).**
- **Setup.** A FU-1 FRESH level within its lifetime: support below price for longs, resistance above price for shorts.
- **Entry.** Limit order at the level.
- **Stop.** 0.5×ATR beyond the level. Variant: beyond the origin candle's wick + 0.1×ATR.
- **Target.** 2R. Variant: the nearest fresh opposite level.
- **Cancel.** The level turns unfresh or flips first, or its lifetime ends.
- **Filters to test:** HTF bias agreement; including gap levels; the close-pivot (N=3) level source.
- **Control (random prior close).** At the same bar, pick a random earlier close from the same lifetime window, on the same side of price, and trade it with the same rules. This is essential because every A/V level is simply an earlier close.

**H9 – MSNR flip retest (RBS/SBR).**
- **Setup.** The first return to a level from its new side after it was flipped by a close.
- **Entry, stop, target.** Limit at the level; stop 0.5×ATR beyond it; target 2R.
- **Control.** A random prior close that price has since closed through.

**H10 – QML.**
- **Setup.** QM-1.
- **Entry.** Buy limit at the QML.
- **Stop.** L_head − 0.5×ATR.
- **Targets.** TP1 at H_b and TP2 at 2R (measure both).
- **Cancel.** A close below L_head; 50 bars; or price runs to H_b + (H_b − QML) before the fill.
- **Variants.** The S37 geometry: SL at head ± ATR21/2, TP at the broken swing and the newest swing.
- **Controls.** RC-X: a limit at the left-shoulder low of swing sequences that did not form the head sweep plus close break. RC-L.

**H11 – First return to a DBO level.**
- **Setup.** A DBO-1 bullish A-level, from confirmBar onward.
- **Entry.** Buy limit at the level.
- **Stop.** Origin candle low − 0.1×ATR. Variant: 0.5×ATR below the level.
- **Target.** 2R.
- **Control.** A random prior close.

**H12 – Breakout baselines.**
- **(a) S34-style.** A close above the 15/15 pivot level (used only from p+16) with the tick-volume oscillator > 20. Enter at the next open; stop at break-bar low − 0.1×ATR; target 2R.
- **(b) S59.** With mult = 0. With mult = 1, exclude breaks within 3 bars of pivot confirmation, because those are mostly immediate breaks built into the line.
- **(c) S61.** The multi-tested-level breakout.
- **Controls.** A Donchian 20-bar close breakout at the same frequency; RC-T.

**H13 – Filters applied to H1–H5 and H8.**
- **Filters to test:**
  - Premium/discount: longs only in the discount half of the MS-1 dealing range. Variant: OTE 0.62–0.79.
  - HTF bias agreement.
  - Break-candle displacement.
  - Session (the S3 killzones converted to UTC with DST).
  - Zone age bucket.
  - First touch vs later touches.
- **Control.** The unfiltered set. Judge by the change in E[R], not in win rate.

**H14 – Price-action trigger inside a zone.**
- **Setup.** A PA-1 bullish engulfing, pin bar or displacement candle that closes with its low inside an active long zone (OB-1, FVG-1 or FU-1).
- **Entry.** Next bar's open.
- **Stop.** Pattern low − 0.1×ATR.
- **Target.** 2R.
- **Controls.** RC-X1: the same pattern outside any zone. RC-X2: a touch of the same zone with no pattern.

**H15 – Liquidity as a target, not a trade.**
- From EQ-1's t_known, measure P(price reaches the EQH/EQL within 20, 50 and 100 bars).
- Compare with an RC-L level at the same distance.
- This decides whether EQH/EQL are useful take-profit targets.

---

## 4. Repainting and look-ahead traps

1. **Back-dated pivots.** Swing objects are drawn at the pivot bar but only known R bars later.
   - Examples: S1 (50 bars, about 4h10m on M5), S34 (16), S50 (14), S59 (14, with backpaint on by default), S35 (10), S13 (5), S2 and S36 (known at the zigzag flip), S54 (25).
   - **Fix:** timestamp the object at confirmation, and allow no touches or entries before that.
2. **Back-dated zone boxes.** OB, FVG and breaker boxes start at the OB candle or at candle 1 or 2, but only exist from the break-bar close or the candle-3 close. S16 only allows an entry after the MSS bar; S38 levels exist from confirmBar.
   - **Fix:** use t_known.
3. **Late relabelling and survivorship.**
   - S38 upgrades a level to "DBO to DBO" long after it was created.
   - S3 resizes liquidity boxes after the fact.
   - S55 deletes failed SFPs.
   - S22 deletes invalidated IFVGs *and their past signals*.
   - S14, S21 and S13 delete mitigated zones.
   - S35 shows only the current channel set, extended across all history.
   - S1, S14 and S15 draw only the state on the last bar.
   - **Fix:** never judge performance from the chart. Replay bar by bar and keep every event.
4. **Intrabar flicker.** No confirmed-bar gate in S1, S3, S4, S14, S19, S21, S22, S34, S36, S37, S52, S58 and S59.
   - Confirmed-bar gated: S15 (drawing), S17, S18, S20, S27, S29, S38, S41, S54, and S25's zones.
   - **Fix:** use closed bars only. Close-based states are decided at bar close. Only wick events and order fills may use tick timing.
5. **Higher-timeframe look-ahead.**
   - S1's HTF FVG uses lookahead_on on the current HTF bar, which leaks the future on history.
   - S49 (okinawan21) uses lookahead_on on the current HTF bar's colour and close, a future leak. Do not use it as a reference.
   - S21, S24, S30 and S46 request the forming HTF bar with lookahead off, so real-time zones differ from what appears after a reload, and phantom zones survive until then.
   - Correct patterns: offset [1] with lookahead_on (S25, and S1's D/W/M levels), or confirmed HTF bars only (S32).
6. **Centred windows.** R1's swing detection uses N bars on both sides without a lag. Shift the result by N bars, or it looks ahead.
7. **Gating on the end of the chart.** Results depend on where the loaded history ends:
   - S3 and S51 "Present" mode (last 500 bars);
   - S15 (1750 bars) and S16 (2000 bars) processing windows;
   - S24's lookback measured from the current wall-clock time;
   - S57's visible range, which recomputes on every scroll.
   - History changes on reload. **Fix:** process all bars from a fixed start date.
8. **History-dependent statistics.** Values change with how much history is loaded:
   - S1's FVG auto threshold and cumulative mean range;
   - S21's auto threshold;
   - S5's probabilities;
   - S2 and S36's initial trend state;
   - S22's warm-up threshold.
   - **Fix:** fixed start plus warm-up, or rolling windows.
9. **Same-bar ordering.**
   - An outside bar that breaks both sides: S5 lets the bearish result win.
   - Created and deleted on the same bar: S13, and S1's OB check on the creation bar.
   - Touches during the confirmation window: S12's follow-through bars can re-enter the zone; S50 counts the pivot's own right-side bars.
   - **Fix:** define and log a fixed order of operations.
10. **Lagged counters.** S50's touch counter runs 14 bars behind.
11. **Strategy tester fills.** TradingView strategies fill market orders at the next bar's open and assume an OHLC path for stops (S63, S65, S66). A real-tick MT5 test gives different results.
12. **Parity issues.**
    - Wilder ATR vs MT5's SMA-based ATR; EMA seeding.
    - Exness tick volume vs TradingView feed volume (affects S13, S15, S18, S34, S50, S57, S58).
    - Exness server-time H4/D1 boundaries vs TradingView.
    - Bid-based bars vs Ask fills.
13. **Overfitting.** The variant grid is large. Keep the 3-month hold-out untouched, and count every variant tried.

---

## 5. Licensing

- **MPL 2.0.** Commercial use is allowed. The copyleft is file-level: a *distributed* file derived from MPL code must stay MPL and its source must be made available. Private use carries no obligation.
  - Scripts: S2, S12, S15, S17, S24, S25, S26, S28, S29, S31, S32, S35, S36, S37, S40, S54, S56, S60 (v2), S61.
- **CC BY-NC-SA 4.0.** Non-commercial only; attribution required; adaptations must use the same license. A line-by-line port of this code into an EA that is sold or used commercially is not allowed.
  - Scripts: S1, S3, S4, S5, S11, S13, S14, S16, S18, S19, S21, S22, S23, S27, S30, S33, S34, S50, S51, S52, S53, S55, S57, S58, S59.
  - S7 is probably NC as well (not verified).
- **Open-source but no license header.** Only TradingView House Rules apply, so no reuse license is granted.
  - Scripts: S20, S38, S41 to S45, S46, S47, S63, and S60 v1.
- **Open-source, header not checked:** S6, S8, S9, S10, S48, S49, S62, and the S64–S66 built-ins.
- **Unavailable:** S39 (the page returns 404 even though it is still listed).
- **Closed (logic from page text only; we did not try to get the code):**
  - MSNR levels by TTQ & Milana (protected): https://www.tradingview.com/script/SwRquE4z-MSNR-levels-by-TTQ-Milana-Trades/
  - Malaysian SnR Levels by trading-guide (invite-only): https://www.tradingview.com/script/20NljIPT-Malaysian-SnR-Levels/ plus its siblings 0cJJ9mUO and KKLcgG6L.
  - Malaysian SnR + Storyline by zacdivan (protected): https://www.tradingview.com/script/zHJLrkfS-Malaysian-SnR-Storyline/
  - ClickNull rqicMTGc; JDani16 j5Slhra9; FxMeng EBP31cIf; ChillOut vXv9ToAv; Jithuze jYg6YsfN; NENO nP6nggln.
  - TFO Inducement / Stop Hunt (protected): https://www.tradingview.com/script/pxCIz9Fh-Inducement-Stop-Hunt-TFO/
  - LuxAlgo Price Action Concepts (invite-only).
  - wugamlo Order Block Finder V2 (invite-only).
- **Non-TradingView:** R1 is under the MIT license.
- **Rule for the project:**
  - Write our own MQL5 and Pine code from the canonical definitions in section 2.
  - Paste no Pine code from any script.
  - The scratchpad source copies are for analysis only.
  - If a published or sold artifact ever implements a specific script's idea closely, credit the author in the docs.
  - The generic ideas (a 3-candle gap, pivots) are not the same thing as the code that expresses them. This is not legal advice.

---

## 6. Performance claims

- **No script makes a verifiable performance claim.** None publishes a backtest with a symbol, timeframe, date range, sample size and costs.
- **S5 (Zeiierman):**
  - The page describes "backtested results" and shows one example: 85% for an upside BMS vs 16.36% for a downside CHoCH.
  - No symbol, timeframe, dates or sample size are given, and the two numbers add up to 101.36% because of a stale denominator in the code.
  - The "Profitability" figure is the hit rate of predicting the type of the next structure event. It is not trading profit: there are no entries, stops, costs or risk-reward.
- **Descriptive statistics only, not edge:**
  - S21 dashboard: FVG count and % mitigated. The "average bars to fill" it advertises is not implemented.
  - S23: "Filled %", counted as a wick through the far edge. Recent unfilled zones stay in the denominator.
  - S4: % of fractals that became structure breaks.
  - S50: touch counts and volume.
  - These can be reproduced, but they say nothing about profitability.
- **Settings, not results:**
  - S16's R:R of 1:2, 1:3 and 1:4 are take-profit settings.
  - S16's "5–10 bars" freshness advice is qualitative and not coded.
  - felipemiransan's "Price Action Strategy" uses SL 16% and TP 9.5% tuned on a crypto perpetual; those are parameters.
  - The S63, S65 and S66 strategy() scripts publish no results. TradingView tester fills would not match MT5 real ticks anyway.
- **Warnings from the authors themselves:**
  - S12: back-dated plots make history look like perfect entries.
  - S22: backtesting the historical on-chart signals is incorrect.
  - S1: there is no supporting data for these concepts, and the script is educational.
  - S59: the lines are backpainted by default.
- **Popularity** (boosts, views, Editors' Pick flags) is not evidence.
- **Conclusion:** any edge must come from our own 9-month tick test using the protocol in section 3.

---

## 7. Open items to check before coding

1. **Pine pivot tie rule** (left ≥, right >). This comes from R3 and was not confirmed against a TradingView chart. Compare pivot bars from our MQL5 port with TradingView on the same data before trusting pivot-based rules.
2. **Pine crossover when the previous close equals the level exactly.** This affects S1, S34 and S35 parity.
3. **Scripts read from page text only** (S6–S10, S62, and S7/S19's swing hierarchy). Read their code before using any of their rules as variants.
4. **Unconfirmed code details:**
   - S24: whether Pine normalises a box whose top and bottom are swapped (this decides whether the bearish-FVG "Full Fill" is correct).
   - S30: whether its mitigated flag is latched or re-evaluated each bar.
   - S40: the source defaults differ from the page text.
5. **Web search limits.** Web search/fetch hit a session limit during the detailed reads, so pages were fetched with plain public HTTP GETs. Pine documentation on tie handling and for...in removal was not re-checked.
6. **Feed parity.** Exness bars and tick volume will not match TradingView feeds, so labels will differ from the chart. Validate the port by the logic itself, not by matching labels one-for-one.