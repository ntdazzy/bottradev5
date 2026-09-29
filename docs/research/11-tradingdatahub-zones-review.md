<!-- Tổng hợp (tiếng Anh) về source cũ C:\Users\NTD\Desktop\TradingDataHub, chỉ đọc, ngày 27/09/2026. -->

**TradingDataHub (TDH) and FVG/OB/S/R zones: what it defines, what it measured, what BotVangLab can reuse**

**Bottom line:** TDH has no evidence of an edge for FVG, OB or S/R zones. The only strategy that traded FVG/OB zones came out about breakeven on 7 in-sample XAU trades, and one trade made the whole profit. The two S/R-type strategies lost on every trade. TDH never ran a first-touch test against random control zones, which is the test BotVangLab uses, so its S/R results don't contradict BotVangLab's no-edge finding. What TDH does offer is precise FVG/OB definitions, zone lifecycle rules, and test rules that can be ported into BotVangLab.

All TDH work was read-only. I opened no .env or credential files and did not touch the recorder that is running under `reports\brain\future-holdout-xau-s1-freshness-v05-20260926`.

---

## 1) What TradingDataHub does

TDH is a Python "trading intelligence hub" with a FastAPI server, Postgres/Redis, a Telegram bot, an LLM (Codex) plan writer, and an MT5 HTTP agent on 127.0.0.1:18090 (`execution\mt5\native.py`). It holds three separate zone engines that share no code:
- **analytics/structure**: runs on OKX/Bybit perpetual prices (BTCUSDT, XAUUSDT), not on Exness (`config.py:31`).
- **market/structure**, policy "structure-v2.1": runs on Exness MT5 BTCUSDm and XAUUSDm at 1m/5m/15m. Three rule-based strategies use it: trend-pullback, range-swing and breakout.
- **brain/perception, "Brain V2"**: XAUUSDm only, D1 down to M1. It covers Malaysian-SNR levels, FVG and liquidity, with setup families S1–S4. It never produced a trade.

It also has TradingView Pine indicators (`docs\pine`). None of them is a Pine `strategy`, so none has a Strategy Tester backtest.

Live trading is blocked: ROADMAP.md:1497 says the final candidates "produce no accepted trades".

## 2) Exact definitions

**Structure / swings**
- **market/structure** (`market\structure\policy.py:17-40`, `swings.py`, `bos.py:17-94`):
  - Pivots use 2 bars left and 2 right. ATR is 14. Tolerance is max(1 tick, 0.05·ATR) and the break buffer is max(1 tick, 0.1·ATR).
  - UP trend means the last high is a higher high and the last low a higher low. DOWN is the mirror.
  - A break is a close beyond level + buffer. It is a BOS if it goes with the trend, otherwise a CHoCH. Breaks only count when the trend is UP or DOWN.
  - A break is "sufficient" when all of these hold: |close−level| ≥ 0.2·ATR, body/range ≥ 0.5, and either force is aligned or the tick-volume percentile is ≥ 75 over 20 bars.
- **Brain** (`brain\perception\swings.py`, `structure.py`): brain-structure-v0.3. External swings are 2/2, internal swings 1/1. A close through the break-target level is a BOS; a close through the protected level is a CHoCH. Wick-only crosses are logged separately.
- **analytics** (`analytics\structure\swings.py`, `events.py`): pivots 2/2 with no tolerance.

**S/R (SNR)**
- **Classical SNR, rule R-01** (`brain\perception\source_zones.py:259-311`; `docs\brain\SOURCE_METHOD_RULEBOOK.md:57-77`):
  - Every bearish→bullish pair of closed candles makes a support; bullish→bearish makes a resistance.
  - The level is the first candle's close, as a single line (lower = upper). Dojis and equal bodies are skipped.
  - There is no filter for size, freshness or higher timeframe. This rule fires on about 50% of M5 bars.
- **Rare GAP_SNR, rule R-02** (`source_zones.py:314-376`): two same-colour candles.
  - Bearish gives resistance [L1, H2]; bullish gives support [L2, H1]. It needs LL ≤ C1 ≤ UL.
  - It is AUDIT_ONLY because the geometry was inferred from PDF diagrams.
  - Rule R-04 invalidates it on the first close beyond UL or LL. The code says it is not an FVG.
- **Role flip, rule R-03** (`source_zones.py:379-770`): only a close flips support to resistance or back; wicks never do.
- **analytics S/R zones** (`analytics\structure\levels.py:65-103`):
  - Takes the last 20 swing lows and 20 swing highs and clusters them within ATR/2. Each zone is the cluster mean ± ATR/4.
  - strength = 0.7·min(1, touches/3) + 0.3·recency. The top 5 zones per side are kept.
- **Pine variants:**
  - `Malaysian SnR Kai[DoN].pine`: close pivots 3/3 with an SMA21 filter, plus SBR/RBS flips.
  - `TradingBot_v4.pine` f_reaction (lines 60-83): colour-change SnR, gap SnR (body ≥ 0.6 ATR) and doji SnR, each zone capped at 0.12 ATR.
  - `TradingBot_v5.pine`: three kinds of SnR ("rare", gap and swing-cluster). A flip only counts after price retests the level (lines 788-849).

**FVG**
- **market/structure** (`market\structure\fvg.py:11-38`):
  - Bullish when bar3.low > bar1.high, zone [bar1.high, bar3.low]; bearish is the mirror.
  - Minimum width is 1 tick. A middle body ≥ ATR only adds a tag; it does not filter.
- **Brain** (`brain\perception\fvg.py:186-501`):
  - Same strict 3-bar geometry with no minimum size. It is confirmed at the close of bar 3, and no FVG can form across a data gap.
  - Fill is measured from the near edge. States: UNTOUCHED, PARTIAL, FULLY_MITIGATED, and INVALIDATED on a close beyond the far edge.
  - It passed a prefix-invariance check (no look-ahead) (`docs\brain\GATE_C_REVIEW.md:52-55, 153-166`). It fires on about 21% of M5 bars.
- **Pine variants:**
  - v4.1 (`TradingBot_v4.pine:199-228`): gap ≥ 0.05 ATR and middle body ≥ 0.45 ATR (0.20 on D1/W1).
  - v5.1 (lines 781-787, 498-524): gap ≥ 0.10 ATR, middle body ≥ 0.40 ATR, nearby FVGs merged, merged height ≤ 2 ATR.
- **analytics** (`analytics\structure\fvg.py`): no minimum size and no close-through invalidation.

**OB (order block)**
- **market/structure** (`market\structure\order_blocks.py:9-40`):
  - Only created on a BOS/CHoCH with sufficient quality (as defined above).
  - The OB is the last opposite-colour candle among the 5 bars before the break. The zone is the full wick range by default (`ob_zone=WICK`).
  - States: TOUCHED, then MITIGATED at 100% fill, or INVALIDATED on a close beyond the far edge (`zone_lifecycle.py:9-43`).
- **Pine v4.1** (`TradingBot_v4.pine:229-255`), stricter:
  - The break must come with an impulse body ≥ 0.8 ATR.
  - The OB is the last opposite candle within 20 bars, no earlier than the broken pivot.
  - It needs a same-direction FVG within 3 bars, must not have been closed through before, and must be ≤ 1.5 ATR tall. The zone is [low, body top].
- **analytics** (`analytics\structure\order_blocks.py`): marks the OB MITIGATED on the first touch.
- **The Brain has no OB detector.** The "411 Engulfing" zones are selected by hand and are AUDIT_ONLY.

**Liquidity** (`brain\perception\liquidity.py`)
- Equal highs/lows: tolerance max(2 ticks, 0.05·ATR).
- Session highs/lows: Asia 09-18 Tokyo, Europe 08-17 London, America 08-17 New York. Previous-day high/low is also a pool.
- A sweep is a wick 1 tick beyond the pool. A close back inside within 3 bars makes it RECLAIMED; otherwise it is CONSUMED.

## 3) Trading method

- **trend-pullback-v2** is the only FVG/OB strategy that was replayed (`strategies\trend_pullback.py:47-365`).
  - **Context:** the 15m trend must be UP or DOWN.
  - **Zone:** the nearest 5m FVG or OB in the trend direction, in state NEW, TOUCHED or PARTIALLY_FILLED. So re-touches are allowed; it is not first-touch only.
  - **Filters:**
    - no longs in premium or shorts in discount;
    - distance to the zone ≤ 1 ATR (3 ATR in the "retest" runs);
    - no trade if force opposes;
    - spread ≤ 5 bps.
  - **Stop:** a 1m/5m swing beyond the zone, at least 2 ticks away.
  - **Target:** the nearest opposite 15m swing (falls back to 5m), with reward/risk ≥ 1.5 checked before costs.
  - **Trigger:** a 1m BOS/CHoCH no older than 180 s (600 s in the retest runs). Entry is a LIMIT order with a 900 s TTL.
  - The optional `require_bos_fvg` mode was never run.
  - **Replay bug (I checked the code):** the strategy computes risk and reward/risk with entry at the far edge (`trend_pullback.py:141`, zone.low for a long). The replay fills the order at the near edge (`references.py:70` via `replay\strategy_runner.py:77`, zone.high for a long). So the 1.5 reward/risk gate is overstated compared with the simulated fill.
- **range-swing-v1:** trades the edges of an ACTIVE 15m range box with quality ≥ 4. It skips the middle 40% of the box, needs price ≤ 0.5 ATR from the edge, and targets the opposite edge with reward/risk ≥ 1.5 (`reports\phase13-range-swing.md:11-27`).
- **breakout-v2:** a close beyond the level by ≥ 0.2 ATR, then a limit order on the retest. Reward/risk ≥ 1.5 is checked after costs (`strategies\breakout.py:51-72`).
- **Brain S1–S4** (`brain\setups.py`, `brain\planning\thesis.py`):
  - S1: pullback into an ACTIVE Classical/GAP area. S2: retest of a flipped SNR level; it is always BLOCKED. S3: sweep and reclaim; it is always BLOCKED. S4: tick-based compression and expansion.
  - Entries are MARKET only. Reward/risk ≥ 1.5 after costs.
  - One reader inferred, without running it, that S1 can almost never get a valid stop, because Classical levels have lower = upper.
- **Filters around the strategies:**
  - Risk (`risk\policy.py:25-47`): 1% risk per trade, 1 position at a time.
  - News: blocked within ±30 minutes of a high-impact release.
  - Session guards; rollover guard 20:50–22:05 UTC.
- **Written but never coded:**
  - ICT sweep → market-structure shift → FVG (`docs\research\msnr-ict-continuous-handoff-2026-09-17.md:233-271`).
  - rare-gap-retest-v1; its output folder is empty.
- **LLM planner lane** (`prompts\plan_creation.py`): picks entry, stop and target references with an LLM. Not reproducible.

## 4) Measured results that passed verification

These are the numbers after the verifier corrections were applied. All are in-sample unless marked otherwise.

| Test | Result | Sample / period | IS/OOS | File |
|---|---|---|---|---|
| **Trend-pullback-v2 FVG/OB**, retest config (3 ATR, 600 s, force OPPOSING_ONLY), after cost fix | **XAU:** 41 intents (34 FVG, 7 OB), 33 never filled, 8 filled, 7 resolved: 3 wins / 4 losses (42.9%). Expectancy +0.055 price units/trade = +0.43R. **Profit factor 1.29 is on gross profit; net PF ≈ 1.01** (`replay\report_metrics.py:78`). Max drawdown 35.45. Net over the 7 resolved trades +0.38; −0.26 including the open trade's entry cost. **One short on 09-11 (+31.76, +4.35R) makes the whole profit; the other 6 trades total ≈ −1.34R.** **BTC:** 1 trade, a loss of −22.64 (−0.65R); gross was +0.88, so costs made it a loss. BTC had no force data. | 10k bars per timeframe. 1m bars: XAU 2026-09-03..09-14, BTC 09-07..09-14 | In-sample. The 3 ATR / 600 s settings came from a 2k-bar sweep on the same data, and that sweep contained the same winning trade (`phase12-replay.md:101-111`) | `reports\phase12-retest-costfix.json`; `reports\phase14-breakout.md:80-92` |
| Same strategy, earlier run (before the cost fix; superseded) | Retest: XAU 47 intents (39 FVG, 8 OB), 9 filled, 4 wins / 4 losses / 1 open, +0.36/trade, +0.54R, PF 1.38 (gross). Default (1 ATR, 180 s): XAU 3 trades, 1 win / 1 loss / 1 open. BTC: 0 trades (default), 1 loss (retest) | Same data, only 3 force samples | In-sample | `reports\phase12-replay.md:116-142` |
| Trend-pullback funnel | 1k bars: 0 intents. Main blockers: no 15m context (BTC 645, XAU 435), wrong premium/discount (125 / 343). 2k bars, v1 entry: 0 trades | 1k and 2k bars | In-sample | `reports\phase12-replay.md:31-114` |
| **Range-swing (S/R range edges)** | BTC 2 trades, 2 losses, net −892.30 (−1.09R). XAU 2 trades, 2 losses, −16.49 (−1.19R). Main blocker NO_RANGE_CONTEXT (BTC 6263, XAU 8231) | 4 trades | In-sample | `reports\phase13-range-swing.md:68-83`; `reports\phase14-breakout.md:86-87` |
| **Breakout-v2 + walk-forward** | XAU retest 0 wins / 2 losses, −7.87; momentum 0/1, −4.17; BTC 0 trades. Walk-forward: 2 trades, expectancy −3.93, PF 0, gate FAIL (fewer than 20 trades, negative expectancy, PF < 1.1). **The walk-forward is out-of-sample in name only:** one continuous replay was split by date, nothing was fitted on the train windows, and the 2 trades are the same 2 trades as above | XAU 1m, 2026-09-03..09-14 | Nominal OOS only | `reports\phase14-breakout.md:94-196`; `reports\phase19-walk-forward.md:36-65` |
| **Brain frozen holdout (S4 only; it does not use SNR/FVG zones)** | 189 full rebuilds, 0 risk-ready setups (20 needed). Blockers: INVALIDATION_UNRESOLVED 152, REWARD_RISK_TOO_LOW 37 | About 38 minutes on 2026-09-21 (19:18–19:57Z) | True future holdout, but it produced no trades | `docs\brain\HOLDOUT_BLOCKER_BREAKDOWN.md:13-29` |
| Brain development replays | 24 sampled moments: S1 BLOCKED 15 / CONTEXT_READY 6; S2 BLOCKED 21 of 21 (NO_FLIPPED_SNR_CONTEXT 20); S3 BLOCKED 21. After the S1 rule change: 960 probes (572 BLOCKED, 388 NO_QUOTE) plus 21 bar-close probes, 0 ready. Live watch: 72 polls, 0 ready | XAU, 2026-09-24/25 | In-sample development replays | `docs\brain\RULE_RELAXATION_PLAN.md:43-51, 107-111`; `reports\brain\bar-close-probe-s1-rules(-small).json` |
| P8 / P11 (S4 setup) | 2 triggers in the unseen part: one had no stop, the other had after-cost reward/risk −0.084. 0 of 20 required samples | XAU 2026-09-10..09-21, split at 09-17 16:48 UTC | Unseen part only; prior exposure not verified | `docs\brain\P11_EMPIRICAL_RUNNER_VALIDATION.md:31-44` |
| Detector counts (not edge) | M5 10k bars: FVG 2,102, Classical SNR 4,976, GAP 4,839, equal-high/low pools 3,047. No-look-ahead (prefix) checks PASS. Structure, 3k bars on M15/M5/M1: BOS 79/85/91, CHoCH 70/66/64 | XAU M5 2026-07-24..09-14 | Not applicable | `docs\brain\GATE_C_REVIEW.md:145-209`; `docs\brain\P3_SOURCE_METHOD_REVIEW.md:104-121`; `docs\TRADING_BRAIN_V2_P9_VALIDATION_REPORT.md:34-38` |
| Pine v4.1 signals, counted by a counter built into the code | M15: 4 signals, 1 hit TP1 first, 3 hit the stop first. H1 and H4: 0 signals. No costs; 200-bar warm-up not met. The build measured used older settings (FVG body 0.8 ATR) than the current file (0.45) | B2PRIME:XAUTUSD, 10–17 Sep 2026 | Not OOS | `docs\pine\QA_V4.md:33-45` |
| Cost and data facts | Spread from 1m bars: XAU mean 0.59 bps (max 1.07), BTC 1.28 bps. Data ends 09-14; 09-16 is only the report date. Slippage never measured. XAU daily break 20:57→22:00 UTC | 10k 1m bars | Not applicable | `reports\phase20-spread-slippage.json`; `reports\phase17-rollover-window.json` |

**Refuted or contradicted claims (do not rely on these):**
- **v3 recorder checkpoint** (`docs\brain\holdout\xau-20260925T2058-v3.capture-checkpoint.json`): refuted by both verifiers.
  - Correct in that file: 654,894 ticks, 1,121 gaps, 1m/5m/15m/1h/4h bars 3,548/720/243/59/10.
  - At that point the recorder was still RECORDING. The "FAILED_CLOSED, 167,664 ticks" figures come from a different file (`reports\brain\future-holdout-xau-memory-v04-v3-20260922\20260925T062217Z-7cc518b3\session-end.json`), and the stop reason was FROZEN_RULE_CHANGED:brain/setups.py.
  - "About 4.5 days" is wrong; it is about 4.1 days (about 59 hours of 1m bars).
- **`RULE_RELAXATION_PLAN.md:36`** says REWARD_RISK_TOO_LOW = 0 in the 170-probe session. Its own JSON (`reports\brain\ignition-window-probe-session.json`) records 33. The document's claim that lowering the reward/risk minimum from 1.5 to 1.2 was "rejected by data" therefore has no support.
- **"Frozen Brain built on SNR/FVG/liquidity memory":** wrong. The holdout covered S4 only. The 1,050 "episodes" figure comes from a separate screen-only scan over 16,222 batches.
- **"PF 1.29" as a net edge:** it is gross; net ≈ 1.01.
- **"Labor Day early close"** as the cause of the 214-minute gap on 09-07: not supported. The project itself calls it a data-collection gap.

## 5) What was never measured

- **First-touch reaction of FVG, OB, Classical SNR, GAP or liquidity zones against random control zones.** No file in TDH does this.
- **FVG versus OB outcomes.** Trades don't record which zone type they came from; only intent counts exist.
- **The Phase 12 research questions** (`ROADMAP.md:884-892`): plain pullback vs BOS+FVG, value of an FVG filter, premium/discount, OB overlap, and the force filter. None has a report, and no run used `require_bos_fvg=true`.
- **Brain S1/S2/S3 outcomes:** zero trades ever.
- **Never coded or never run:**
  - the ICT sweep→MSS→FVG spec;
  - MSNR V1;
  - rare-gap-retest-v1 (its folder `reports\msnr-v1\rare-gap-retest-v1\` is empty);
  - the legacy SetupEngine;
  - Pine v5.1 signals;
  - the 01–10 Sep Pine validation builds, which have no recorded results.
- **Data gaps:** real slippage, ETHUSDm, BTC ticks, BTC timeframes above 15m, and any period longer than about 11 days of 1m data.
- **Human labels:** the review packs are empty. The only labels (2 of 6 agree, 33%) were drafted by the assistant.

## 6) What BotVangLab can reuse

**Worth porting to MQL5.** Treat these as parameterised zone types, each measured on first touch against random controls:
- **FVG:** the strict Brain rule (`brain\perception\fvg.py`): confirmed at the close of bar 3, fill measured from the near edge, invalidated on a close beyond the far edge, never formed across a data gap. Test filter levels as parameters:
  - 1 tick minimum (market/structure);
  - gap 0.05 ATR + middle body 0.45 ATR (Pine v4.1);
  - gap 0.10 ATR + body 0.40 ATR + merge (Pine v5.1).
- **OB:** `market\structure\order_blocks.py` plus the break-quality rules in `bos.py` (0.2 ATR close distance, body ≥ 0.5, tick-volume percentile ≥ 75 over 20 bars, lookback 5, wick zone). As a stricter variant, the Pine v4.1 rules (impulse ≥ 0.8 ATR, FVG within 3 bars, not closed through before, height ≤ 1.5 ATR).
  - **Timestamp the OB at the moment the break is confirmed, not at the OB candle.** Otherwise the test uses future information.
- **Zone lifecycle:** `zone_lifecycle.py`. "New touch" rule from Pine v4.1 (lines 647-656): a touch only counts again after price has left the zone by 0.4 ATR. This gives a clean definition of "first touch".
- **Structure and liquidity:** pivots 2/2, tolerance max(1 tick, 0.05 ATR), buffer 0.1 ATR. Equal highs/lows, session pools and sweep/reclaim within 3 bars from `liquidity.py`.
- **Test rules:** a bar that hits both stop and target counts as AMBIGUOUS (conservative). Walk-forward gate: at least 20 resolved trades, expectancy > 0, PF ≥ 1.1. Stress runs at 3 bps spread, 3 bps slippage and 2 s latency (`replay\walk_forward.py`). XAU daily-break calendar (`brain\calendar.py`).
- **Data for cross-checking MQL5 detections bar by bar against the Python detectors:**
  - XAUUSDm H1 from 2025-01, H4 from 2020-06, D1 from 2014-01 (`reports\msnr-v1\bars-xau-*.jsonl`).
  - Symbol specs: `reports\phase6-broker-specs.json`.

**Not worth reusing:**
- The Python infrastructure: MT5 agent, Postgres (OKX/Bybit data only), Telegram, the LLM plan lane, Docker.
- The analytics stack, because it runs on OKX prices.
- The Brain S1–S4 and thesis machinery.
- The Rare GAP and 411 rules, which are audit-only or chosen by hand.
- Classical SNR as it stands; it fires on half of all bars.
- LuxAlgo SMC code (licence CC BY-NC-SA 4.0, and its higher-timeframe FVG uses look-ahead).
- Any TDH result as evidence of an edge.

## 7) Risks and caveats

- **Look-ahead:**
  - LuxAlgo's higher-timeframe FVG uses `lookahead_on` (line 635).
  - `Malaysian SnR Kai` requests higher-timeframe data without the [1] offset (line 191), so live values can differ from history.
  - The old analytics OB code had a look-ahead bug that was later fixed.
  - Correct pattern (Pine v4.1): use only closed higher-timeframe bars, i.e. iClose(shift=1) in MQL5.
- **Tiny samples and data mining:** 1–9 trades per configuration, about 7–11 days of data. The settings were chosen on the same data. The only positive FVG/OB result depends on one trade.
- **Replay errors:**
  - The fill price does not match the reward/risk check (far edge vs near edge, confirmed in code).
  - Trend-pullback checks reward/risk before costs.
  - The earlier replays counted the entry cost twice (`reports\phase14-fix-brief.md` BUG-1).
- **Rules that cannot be coded as written:** Rare GAP geometry (inferred from PDFs), 411 candle selection (manual), Fresh/Non-Fresh, Doji_SNR thresholds, S2 freshness, and the "three touches" claim.
- **LLM involvement:**
  - The Codex plan lane is not reproducible.
  - The labels were drafted by the assistant.
  - Agent-written markdown contradicts its own JSON in at least one place. Trust the JSON over the .md.
  - Some referenced output files were deleted (per `CODEX_HANDOFF.md`), so some numbers exist only in the docs.
- **Feed differences:** all TDH data is from an Exness demo feed. Pine used B2PRIME. Tick-volume filters depend on the broker.
- **Overlap with BotVangLab's test period:** the Aug–Sep 2026 TDH data probably falls inside BotVangLab's 30% out-of-sample part. The split date is not in TDH, so I can't confirm this. Don't tune FVG/OB rules on those windows.