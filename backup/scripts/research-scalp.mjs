// Nghiên cứu nến/EMA độc lập, không gửi lệnh và không tự chỉnh tham số EA. SPEC 26.3.
import { createReadStream } from 'node:fs';
import { writeFile } from 'node:fs/promises';
import { createInterface } from 'node:readline';
import { createHash } from 'node:crypto';
import assert from 'node:assert/strict';

const minute = 60000;
const lengths = [20, 50, 200];
const timeframes = [5, 15, 60];
const header = 'time;open;high;low;close;tick_volume;spread_price;atr;rsi;activity;h1;h4;d1;known_at';
const labels = { baseline: 'Mọi nến (đối chiếu)', wick: 'Rút râu', engulf: 'Nhấn chìm', break_retest: 'Phá rồi chạm lại cực trị nến' };
for (const tf of timeframes) for (const n of lengths) labels[`ema_${tf}_${n}`] = `Chạm EMA${n} ${tf === 60 ? 'H1' : `M${tf}`}`;

function timestamp(text) {
  if (!/^\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2}$/.test(text)) throw Error(`Ngày không hợp lệ: ${text}`);
  // UTC chỉ dùng làm trục số; KHÔNG suy ra múi giờ sàn hay chuyển thời gian nguồn.
  const result = Date.parse(text.replaceAll('.', '-').replace(' ', 'T') + 'Z');
  if (!Number.isFinite(result)) throw Error('Không đọc được ngày nguồn');
  return result;
}
function emaState() { return { count: 0, sum: 0, values: [0, 0, 0], slot: null, close: 0 }; }
function updateEma(state, close) {
  state.count++;
  state.sum += close;
  lengths.forEach((n, i) => {
    if (state.count <= n) state.values[i] = state.sum / state.count;
    else state.values[i] += 2 / (n + 1) * (close - state.values[i]);
  });
}
function location(b, dir) { return b.high > b.low ? (dir > 0 ? b.close - b.low : b.high - b.close) / (b.high - b.low) : 0; }
function patterns(a, p, b, dir) {
  const names = ['baseline'];
  const body = Math.abs(b.close - b.open);
  const wick = dir > 0 ? Math.min(b.open, b.close) - b.low : b.high - Math.max(b.open, b.close);
  if (location(b, dir) < 2 / 3) return names;
  if (wick >= 2 * body && wick >= 0.5 * b.atr && dir * (b.close - b.open) >= 0) names.push('wick');
  const engulf = dir > 0
    ? p.close < p.open && b.close > b.open && b.close >= p.open && b.open <= p.close
    : p.close > p.open && b.close < b.open && b.close <= p.open && b.open >= p.close;
  if (engulf && body > Math.abs(p.close - p.open)) names.push('engulf');
  const level = dir > 0 ? a.high : a.low;
  if (dir * (p.close - level) > 0 && dir * (p.close - p.open) >= 0.8 * p.atr
      && (dir > 0 ? b.low <= level : b.high >= level) && dir * (b.close - level) > 0
      && dir * (b.close - b.open) > 0) names.push('break_retest');
  return names;
}
function observeEmas(states, touches, b) {
  const hits = [];
  for (const tf of timeframes) {
    const state = states[tf];
    const slot = Math.floor(b.time / (tf * minute));
    // Chỉ đưa nến khung lớn vào EMA khi nó đã kết thúc TRƯỚC lúc M1 này mở.
    if (state.slot !== null && slot > state.slot) updateEma(state, state.close);
    state.slot = slot;
    lengths.forEach((n, j) => {
      if (state.count < n) return;
      const value = state.values[j], name = `ema_${tf}_${n}`;
      const hit = b.low <= value && b.high >= value;
      for (const dir of [1, -1]) {
        const key = `${name}:${dir}`;
        if (hit && !touches.get(key) && dir * (b.open - value) > 0 && dir * (b.close - value) > 0
            && location(b, dir) >= 2 / 3 && dir * (b.close - b.open) >= 0) hits.push({ name, dir });
        touches.set(key, hit);
      }
    });
    state.close = b.close;
  }
  return hits;
}
async function loadCandles(path) {
  const rows = [], states = Object.fromEntries(timeframes.map(tf => [tf, emaState()])), touches = new Map();
  const quality = { rows: 0, gaps: 0, lateRows: 0, zeroTickVolume: 0, zeroSpread: 0 };
  const digest = createHash('sha256');
  const input = createReadStream(path); input.on('data', chunk => digest.update(chunk));
  let lineNumber = 0, last = -Infinity;
  for await (const line of createInterface({ input, crlfDelay: Infinity })) {
    lineNumber++;
    if (lineNumber === 1) { if (line.replace(/^\uFEFF/, '') !== header) throw Error('Sai cấu trúc CSV nến'); continue; }
    if (!line) continue;
    const cells = line.split(';');
    if (cells.length !== 14 || cells.some(value => value.trim() === '')) throw Error(`Thiếu cột dòng ${lineNumber}`);
    const values = cells.slice(1, 13).map(Number);
    if (values.some(value => !Number.isFinite(value))) throw Error(`Số không hợp lệ dòng ${lineNumber}`);
    const [open, high, low, close, volume, spread, atr, rsi, activity, h1, h4, d1] = values;
    const b = { time: timestamp(cells[0]), known: timestamp(cells[13]), text: cells[0], open, high, low, close, volume, spread, atr, rsi, activity, h1, h4, d1 };
    if (b.time <= last || low <= 0 || high < Math.max(open, close) || low > Math.min(open, close)
        || volume < 0 || spread < 0 || atr <= 0 || b.known < b.time + minute || ![-1, 0, 1].includes(h1)) {
      throw Error(`Dữ liệu nến sai/thứ tự trùng dòng ${lineNumber}`);
    }
    if (last > 0 && b.time - last > minute) quality.gaps++;
    if (b.known > b.time + minute) quality.lateRows++;
    if (volume === 0) quality.zeroTickVolume++;
    if (spread === 0) quality.zeroSpread++;
    b.emaHits = observeEmas(states, touches, b);
    rows.push(b); last = b.time;
  }
  quality.rows = rows.length;
  quality.higherBars = Object.fromEntries(timeframes.map(tf => [tf, states[tf].count]));
  return { rows, quality, sha256: digest.digest('hex') };
}
function contiguous(rows, i) {
  for (let j = i - 2; j <= i + 5; j++) {
    if (rows[j].time !== rows[i].time + (j - i) * minute || rows[j].known !== rows[j].time + minute) return false;
  }
  return true;
}
function study(rows, slip) {
  const groups = new Map();
  let windows = 0, excluded = 0;
  for (let i = 2; i + 5 < rows.length; i++) {
    if (!contiguous(rows, i)) { excluded++; continue; }
    windows++;
    const b = rows[i], entry = rows[i + 1], end = rows[i + 5];
    const quarter = `${new Date(b.time).getUTCFullYear()}-Q${Math.floor(new Date(b.time).getUTCMonth() / 3) + 1}`;
    for (const dir of [1, -1]) {
      const names = [...patterns(rows[i - 2], rows[i - 1], b, dir), ...b.emaHits.filter(hit => hit.dir === dir).map(hit => hit.name)];
      const alignment = b.h1 === 0 ? 'H1_chua_ro' : b.h1 === dir ? 'cung_H1' : 'nguoc_H1';
      const movement = dir * (end.close - entry.open);
      const proxy = movement - (dir > 0 ? entry.spread : end.spread) - 2 * slip;
      for (const name of names) for (const period of ['ALL', quarter]) for (const side of ['both', dir > 0 ? 'buy' : 'sell']) {
        const key = `${name}|${period}|${alignment}|${side}`;
        if (!groups.has(key)) groups.set(key, { name, period, alignment, side, n: 0, movement: 0, proxy: 0, positive: 0, aboveCost: 0, days: new Map() });
        const group = groups.get(key);
        group.n++; group.movement += movement; group.proxy += proxy;
        if (movement > 0) group.positive++;
        if (proxy > 0) group.aboveCost++;
        const day = b.text.slice(0, 10), previous = group.days.get(day) ?? { n: 0, sum: 0 };
        previous.n++; previous.sum += proxy; group.days.set(day, previous);
      }
    }
  }
  return { windows, excluded, results: [...groups.values()].map(g => ({
    name: g.name, label: labels[g.name], period: g.period, alignment: g.alignment, side: g.side, samples: g.n,
    days: g.days.size, meanMove: g.movement / g.n, meanAfterCostProxy: g.proxy / g.n,
    positiveMovePct: 100 * g.positive / g.n, aboveCostProxyPct: 100 * g.aboveCost / g.n,
    equalDayMeanProxy: [...g.days.values()].reduce((sum, day) => sum + day.sum / day.n, 0) / g.days.size,
    positiveDays: [...g.days.values()].filter(day => day.sum > 0).length,
  })) };
}
function selfTest() {
  assert.equal(timestamp('2026.01.01 00:01:00') - timestamp('2026.01.01 00:00:00'), minute);
  assert.throws(() => timestamp('not-a-date'));
  const state = emaState();
  for (let i = 0; i < 20; i++) updateEma(state, 100);
  assert.equal(state.values[0], 100); updateEma(state, 121);
  assert.ok(Math.abs(state.values[0] - 102) < 1e-10);
  const states = Object.fromEntries(timeframes.map(tf => [tf, emaState()])), touches = new Map();
  states[5] = { count: 20, sum: 2000, values: [100, 100, 100], slot: 0, close: 100 };
  const bar = { time: 2 * minute, open: 101, high: 102, low: 99, close: 101.8, atr: 1 };
  assert.ok(observeEmas(states, touches, bar).some(h => h.name === 'ema_5_20' && h.dir === 1));
  assert.equal(states[5].values[0], 100); // nến M5 đang chạy chưa đổi đường.
  assert.ok(!observeEmas(states, touches, { ...bar, time: 3 * minute }).some(h => h.name === 'ema_5_20'));
  const rows = Array.from({ length: 8 }, (_, i) => ({ ...bar, time: i * minute, known: (i + 1) * minute, text: `2026.01.01 00:0${i}:00`, open: 100, close: 100 + i, high: 110, low: 99, spread: 0.3, h1: 1, emaHits: [] }));
  assert.ok(contiguous(rows, 2));
  const result = study(rows, 0.5).results.find(r => r.name === 'baseline' && r.period === 'ALL' && r.alignment === 'cung_H1' && r.side === 'both');
  assert.equal(result.samples, 1); assert.equal(result.meanMove, 7); assert.ok(Math.abs(result.meanAfterCostProxy - 5.7) < 1e-10);
  const sell = study(rows, 0.5).results.find(r => r.name === 'baseline' && r.period === 'ALL' && r.alignment === 'nguoc_H1' && r.side === 'sell');
  assert.equal(sell.meanMove, -7); assert.ok(Math.abs(sell.meanAfterCostProxy + 8.3) < 1e-10);
  rows[4].known += minute; assert.ok(!contiguous(rows, 2)); assert.equal(study(rows, 0.5).windows, 0);
  console.log('research-scalp self-test: PASS (time, EMA seed, no future EMA, unique touch, forward window, gap rejection, cost arithmetic)');
}
if (process.argv.includes('--self-test')) selfTest();
else {
  const args = process.argv.slice(2);
  const value = name => { const i = args.indexOf(name); return i < 0 ? undefined : args[i + 1]; };
  const source = value('--input'), output = value('--output'), slip = Number(value('--slip') ?? 0.5);
  if (!source || !output || !Number.isFinite(slip) || slip < 0) throw Error('Dùng: node scripts/research-scalp.mjs --input nen_M1.csv --output report.json [--slip 0.5]');
  const input = await loadCandles(source);
  if (input.rows.length < 8) throw Error('Không đủ nến liên tiếp');
  const report = { source, sourceSha256: input.sha256, created: new Date().toISOString(), first: input.rows[0].text, last: input.rows.at(-1).text,
    horizonMinutes: 5, slipPerLeg: slip, quality: input.quality,
    limitations: ['Nghiên cứu khám phá trên lịch sử đã xem; không phải kiểm tra độc lập.', 'Mẫu có thể chồng nhau. Tỷ lệ đi đúng chiều KHÔNG phải tỷ lệ thắng của EA.',
      'Chi phí xấp xỉ từ spread trong nến và đệm trượt; chưa có SL/TP, hoa hồng, độ trễ hoặc giả lập khớp.',
      'EMA dựng từ M1 theo giờ nguồn, chỉ nến khung lớn đã đóng. Bỏ giai đoạn chưa đủ 20/50/200 nến khung lớn.',
      'Cần so EMA tổng hợp với nến khung lớn của broker trước khi dùng làm tín hiệu giao dịch.'], ...study(input.rows, slip) };
  await writeFile(output, JSON.stringify(report, null, 2) + '\n', { flag: 'wx' });
  console.log(JSON.stringify({ quality: report.quality, windows: report.windows, excluded: report.excluded,
    aligned: report.results.filter(r => r.period === 'ALL' && r.side === 'both' && r.alignment === 'cung_H1') }, null, 2));
}
