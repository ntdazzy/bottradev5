// runner2.mjs — bản đo sau kiểm toán (29/09): đối chứng cùng hình học, gộp 10 lần rải, tuổi cố định như nhau, lệnh chờ khớp đúng giá.
// Dùng: node runner2.mjs <tên_phương_pháp> <discovery|validation> '<cfg json>'
// cfg riêng của runner: _only {nhãn: giá trị | [giá trị]} lọc cản và lệnh theo nhãn; _life_h tuổi cản khi đo (giờ, mặc định 120);
// _maxTouches (mặc định 3); _seeds số lần rải cản giả / lệnh ngẫu nhiên (mặc định 10).
import * as L from './lib.mjs';
import fs from 'fs';
import crypto from 'crypto';

const [, , name, split = 'discovery', cfgArg = '{}'] = process.argv;
if (!name || !L.SPLIT[split] || split === 'lockbox') { console.error('dùng: node runner2.mjs <tên> <discovery|validation> [cfg]'); process.exit(1); }
const cfg = JSON.parse(cfgArg);
const life = (cfg._life_h || 120) * 3600000, seeds = cfg._seeds || 10, maxT = cfg._maxTouches || 3;
const range = split === 'discovery' ? ['2025-03-01', L.SPLIT.discovery[1]] : L.SPLIT.validation;
const from_t = Date.parse(range[0] + 'T00:00:00Z'), to_t = Date.parse(range[1] + 'T00:00:00Z');
const m = L.loadM1(split === 'discovery' ? '2025-01-01' : new Date(from_t - 60 * 86400000).toISOString().slice(0, 10), range[1]);
const tf = {};
for (const k of ['M5', 'M15', 'M30', 'H1', 'H4', 'D1', 'W1']) { const bars = L.resample(m, L.TF[k]); tf[k] = { bars, atr: L.atr(bars) }; }
const data = { m, from_t, to_t, tf };
const pass = tags => !cfg._only || Object.entries(cfg._only).every(([k, v]) => [].concat(v).map(String).includes(String((tags || {})[k])));

const mod = await import(`./methods/${name}.mjs`);
const t0 = Date.now();
const allLevels = (mod.levels(data, cfg) || []);
const levels = allLevels.filter(x => x.known_t >= from_t && x.known_t < to_t && pass(x.tags)).map(x => ({ ...x, expire_t: x.known_t + life }));
let fakes = [];
for (let s = 1; s <= seeds; s++) fakes = fakes.concat(L.makePlacebo(m, tf.H1.bars, tf.H1.atr, levels, 1000 + s, life));
const rows = L.probe(m, tf.M5.atr, tf.M5.bars, levels.concat(fakes), { maxTouches: maxT });
const days = (to_t - from_t) / 86400000 * 5 / 7;
const tagKeys = r => ['tat_ca', 'lan=' + Math.min(r.touch_no, 2)].concat(Object.entries(r.tags || {}).map(([k, v]) => `${k}=${v}`));
const out = { method: name, split, cfg, runner: 'runner2', seeds, life_h: life / 3600000,
  levels_per_day: +(levels.length / days).toFixed(2), overlap: L.overlapStats(levels, rows.slice(0, 20000)), probe: L.summarize(rows, tagKeys) };

if (mod.signals) {
  const sigs = (mod.signals(data, allLevels, cfg) || []).filter(s => s.t >= from_t && s.t < to_t && pass(s.tags));
  const lim = sigs.filter(s => s.limit != null), mkt = sigs.filter(s => s.limit == null);
  const trs = L.simulate(m, mkt).concat(L.simulateLimit(m, lim));
  // đối chứng: seeds bản mỗi lệnh, cùng giờ trong ngày, ngày khác (±1..20 ngày), chiều ngẫu nhiên, cùng khoảng dừng/chốt
  const r = L.rng(77), ctrl = [];
  for (const x of trs) for (let k = 0; k < seeds; k++) {
    const t = (x.fill_t || x.t) + (1 + Math.floor(r() * 20)) * 86400000 * (r() < 0.5 ? -1 : 1);
    if (t < from_t || t >= to_t) continue;
    const i = L.idxAt(m, t); if (i >= m.n) continue;
    const px = m.o[i], dir = r() < 0.5 ? 1 : -1, d = Math.abs(x.entry - x.sl), tp = x.tp != null ? Math.abs(x.tp - x.entry) : null;
    ctrl.push({ t, dir, sl: px - dir * d, tp: tp != null ? px + dir * tp : null, maxMin: x.maxMin });
  }
  const trc = L.simulate(m, ctrl);
  const sorted = [...trs].sort((a, b) => b.R - a.R);
  const month = {};
  for (const x of trs) { const k = new Date(x.t).toISOString().slice(0, 7); month[k] = +((month[k] || 0) + x.R).toFixed(2); }
  const mid = (from_t + to_t) / 2;
  const byTag = {};
  for (const x of trs) for (const key of ['tat_ca'].concat(Object.entries(x.tags || {}).map(([k, v]) => `${k}=${v}`))) (byTag[key] ||= []).push(x);
  out.trades = { n_signals: sigs.length, filled: trs.length, per_day: +(trs.length / days).toFixed(2),
    all: L.statR(trs), random: L.statR(trc),
    without_top3: L.statR(sorted.slice(3)), capped5: L.statR(trs.map(x => ({ R: Math.min(x.R, 5) }))),
    half1: L.statR(trs.filter(x => x.t < mid)), half2: L.statR(trs.filter(x => x.t >= mid)), month,
    by_tag: Object.fromEntries(Object.entries(byTag).map(([k, v]) => [k, L.statR(v)])) };
}
out.seconds = +((Date.now() - t0) / 1000).toFixed(1);
fs.mkdirSync('results2', { recursive: true });
const h = crypto.createHash('sha1').update(cfgArg).digest('hex').slice(0, 10);
const file = `results2/${name}_${split}_${h}.json`;
fs.writeFileSync(file, JSON.stringify(out, null, 1));
const tc = out.probe.find(p => p.key === 'tat_ca');
console.log(JSON.stringify({ file, levels_per_day: out.levels_per_day, overlap_p50: out.overlap.p50, probe: tc,
  trades: out.trades && { all: out.trades.all, random: out.trades.random, without_top3: out.trades.without_top3, half1: out.trades.half1, half2: out.trades.half2 } }));
