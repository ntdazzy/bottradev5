// runner.mjs — đo MỌI phương pháp theo cùng một cách (SPEC 24.6).
// Dùng: node runner.mjs <tên_phương_pháp> <discovery|validation> [cau_hinh_json]
// Phương pháp là file methods/<tên>.mjs, xuất:
//   levels(data, cfg)  -> mảng cản {id, side:+1/-1, lo, hi, known_t, expire_t, atr_src, tags:{...}}  (bắt buộc)
//   signals(data, levels, cfg) -> mảng lệnh {t, dir, sl, tp, maxMin, tags:{...}}                      (tùy chọn)
// data = { m (M1), from_t, to_t, tf: { M5:{bars, atr}, M15:..., M30, H1, H4, D1, W1 } }
// Chỉ được dùng thông tin đã biết tại thời điểm quyết định (known_t / t của lệnh). Phần KHÓA 07–09/2026 không đọc được.
import * as L from './lib.mjs';
import fs from 'fs';

const [, , name, split = 'discovery', cfgArg] = process.argv;
if (!name || !L.SPLIT[split] || split === 'lockbox') { console.error('dùng: node runner.mjs <tên> <discovery|validation> [cfg]'); process.exit(1); }
const cfg = cfgArg ? JSON.parse(cfgArg) : {};
const WARM_DAYS = 60;
// Tìm luật: đo từ 2025-03-01 (2 tháng đầu 2025 làm nền cho khung lớn). Kiểm lại: 01–06/2026, nền từ 11–12/2025.
const range = split === 'discovery' ? ['2025-03-01', L.SPLIT.discovery[1]] : L.SPLIT.validation;
const from_t = Date.parse(range[0] + 'T00:00:00Z'), to_t = Date.parse(range[1] + 'T00:00:00Z');
const loadFrom = new Date(from_t - WARM_DAYS * 86400000).toISOString().slice(0, 10);
const m = L.loadM1(split === 'discovery' ? '2025-01-01' : loadFrom, range[1]);
const tf = {};
for (const k of ['M5', 'M15', 'M30', 'H1', 'H4', 'D1', 'W1']) { const bars = L.resample(m, L.TF[k]); tf[k] = { bars, atr: L.atr(bars) }; }
const data = { m, from_t, to_t, tf };

const mod = await import(`./methods/${name}.mjs`);
const t0 = Date.now();
const levels = (mod.levels(data, cfg) || []).filter(x => x.expire_t > from_t && x.known_t < to_t);
for (const x of levels) if (!(x.hi >= x.lo) || !(x.known_t > 0) || (x.side !== 1 && x.side !== -1)) throw new Error('cản sai định dạng: ' + JSON.stringify(x));
const fakes = L.makeFakes(levels);
const rows = L.probe(m, tf.M5.atr, tf.M5.bars, levels.concat(fakes), { maxTouches: cfg.maxTouches || 3 })
  .filter(r => r.t >= from_t && r.t < to_t);
const days = (to_t - from_t) / 86400000 * 5 / 7;
const tagKeys = r => ['tat_ca', 'lan=' + Math.min(r.touch_no, 2)].concat(Object.entries(r.tags || {}).map(([k, v]) => `${k}=${v}`));
const out = {
  method: name, split, cfg, seconds: 0,
  levels_per_day: +(levels.length / days).toFixed(1),
  overlap: L.overlapStats(levels, rows.slice(0, 20000)),
  probe: L.summarize(rows, tagKeys),
};
// Lệnh: so với vào ngẫu nhiên cùng giờ trong ngày, ngày khác trong cùng phần dữ liệu, cùng khoảng dừng lỗ/chốt lời.
if (mod.signals) {
  const sigs = (mod.signals(data, levels, cfg) || []).filter(s => s.t >= from_t && s.t < to_t);
  const trs = L.simulate(m, sigs);
  const r = L.rng(7);
  const ctrl = [];
  for (const s of sigs) for (let k = 0; k < 2; k++) {
    const dayShift = (1 + Math.floor(r() * 20)) * 86400000 * (r() < 0.5 ? -1 : 1);
    const t = s.t + dayShift;
    if (t < from_t || t >= to_t) continue;
    const i = L.idxAt(m, t);
    if (i >= m.n) continue;
    const px = m.o[i], d1 = Math.abs(s.sl - (s.entry_ref ?? m.o[L.idxAt(m, s.t)]));
    const dir = r() < 0.5 ? 1 : -1;
    const tpd = s.tp != null ? Math.abs(s.tp - (s.entry_ref ?? m.o[L.idxAt(m, s.t)])) : null;
    ctrl.push({ t, dir, sl: px - dir * d1, tp: tpd != null ? px + dir * tpd : null, maxMin: s.maxMin, tags: s.tags });
  }
  const trc = L.simulate(m, ctrl);
  const byTag = {};
  for (const x of trs) for (const key of ['tat_ca'].concat(Object.entries(x.tags || {}).map(([k, v]) => `${k}=${v}`))) (byTag[key] ||= []).push(x);
  out.trades = { signals_per_day: +(sigs.length / days).toFixed(2), all: L.statR(trs), random: L.statR(trc),
    by_tag: Object.fromEntries(Object.entries(byTag).map(([k, v]) => [k, L.statR(v)])) };
}
out.seconds = +((Date.now() - t0) / 1000).toFixed(1);
fs.mkdirSync('results', { recursive: true });
const file = `results/${name}_${split}${cfgArg ? '_' + Buffer.from(cfgArg).toString('base64url').slice(0, 12) : ''}.json`;
fs.writeFileSync(file, JSON.stringify(out, null, 1));
console.log(JSON.stringify({ file, levels_per_day: out.levels_per_day, overlap: out.overlap, tat_ca: out.probe.find(p => p.key === 'tat_ca'), trades: out.trades && { all: out.trades.all, random: out.trades.random } }));
