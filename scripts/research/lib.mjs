// lib.mjs — bộ công cụ nghiên cứu cản trên nến M1 XAUUSD Dukascopy (SPEC 24.6). CHỈ để nghiên cứu, không phải bot.
// Quy ước: thời gian là mili giây UTC; nến có t = giờ mở; nến chỉ được dùng từ lúc đóng (t + chu kỳ).
import fs from 'fs';
import path from 'path';

export const DATA_DIR = process.env.DUKA_DIR || '/tmp/claude-0/-home-user-bottradev5/af7de232-0909-5609-b39b-6378847ffc36/scratchpad/duka/d1';
// Chia dữ liệu (SPEC 24.6): tìm luật 2025, kiểm 01–06/2026, KHÓA 07–09/2026.
export const SPLIT = {
  discovery: ['2025-01-01', '2026-01-01'],
  validation: ['2026-01-01', '2026-07-01'],
  lockbox: ['2026-07-01', '2026-09-28'],
};
export const COST = { spread: 0.16, slip: 0.3 }; // giá USD; trượt mỗi chặng
export const MIN = 60000;
export const TF = { M1: 1, M5: 5, M15: 15, M30: 30, H1: 60, H4: 240, D1: 1440, W1: 10080 };

// ---------------------------------------------------------------- dữ liệu
// Đọc M1 trong [from, to). Không cho đọc phần khóa trừ khi OPEN_LOCKBOX=yes.
export function loadM1(from, to) {
  if (to > SPLIT.lockbox[0] && process.env.OPEN_LOCKBOX !== 'yes')
    throw new Error(`Phần dữ liệu ${SPLIT.lockbox[0]}..${SPLIT.lockbox[1]} đang KHÓA (SPEC 24.6)`);
  const files = fs.readdirSync(DATA_DIR).filter(f => f.endsWith('.csv') && f.slice(0, 10) >= from.slice(0, 10) && f.slice(0, 10) < to.slice(0, 10)).sort();
  const rows = [];
  for (const f of files) {
    const txt = fs.readFileSync(path.join(DATA_DIR, f), 'utf8');
    for (const line of txt.split('\n')) {
      if (!line) continue;
      const p = line.split(',');
      rows.push([+p[0], +p[1], +p[2], +p[3], +p[4]]);
    }
  }
  rows.sort((a, b) => a[0] - b[0]);
  const n = rows.length;
  const m = { n, t: new Float64Array(n), o: new Float64Array(n), h: new Float64Array(n), l: new Float64Array(n), c: new Float64Array(n) };
  for (let i = 0; i < n; i++) { m.t[i] = rows[i][0]; m.o[i] = rows[i][1]; m.h[i] = rows[i][2]; m.l[i] = rows[i][3]; m.c[i] = rows[i][4]; }
  return m;
}

// Khóa nhóm nến của khung `min` phút (UTC). Tuần bắt đầu Chủ nhật 00:00 UTC (vàng mở tuần tối Chủ nhật).
export function bucket(t, min) {
  if (min === TF.W1) { const day = Math.floor(t / 86400000); const ws = Math.floor((day - 3) / 7) * 7 + 3; return ws * 86400000; }
  return Math.floor(t / (min * MIN)) * min * MIN;
}

// Dựng nến khung lớn từ M1. Mỗi nến: t (mở), close_t (đóng = được biết), o,h,l,c, i0,i1 (chỉ số M1 đầu/cuối).
export function resample(m, min) {
  const bars = [];
  let cur = null;
  for (let i = 0; i < m.n; i++) {
    const b = bucket(m.t[i], min);
    if (!cur || cur.t !== b) {
      if (cur) bars.push(cur);
      cur = { t: b, close_t: min === TF.W1 ? b + 7 * 86400000 : b + min * MIN, o: m.o[i], h: m.h[i], l: m.l[i], c: m.c[i], i0: i, i1: i };
    } else { cur.h = Math.max(cur.h, m.h[i]); cur.l = Math.min(cur.l, m.l[i]); cur.c = m.c[i]; cur.i1 = i; }
  }
  if (cur) bars.push(cur);
  // Nến cuối có thể chưa đóng trong dữ liệu: vẫn giữ, close_t cho biết lúc được dùng.
  return bars;
}

// ATR Wilder 14; atr[i] biết lúc nến i đóng.
export function atr(bars, n = 14) {
  const a = new Float64Array(bars.length);
  let v = 0;
  for (let i = 0; i < bars.length; i++) {
    const b = bars[i], pc = i > 0 ? bars[i - 1].c : b.o;
    const tr = Math.max(b.h - b.l, Math.abs(b.h - pc), Math.abs(b.l - pc));
    v = i === 0 ? tr : (i < n ? (v * i + tr) / (i + 1) : (v * (n - 1) + tr) / n);
    a[i] = v;
  }
  return a;
}

// Đỉnh/đáy fractal N nến mỗi bên (chặt). known_t = lúc nến i+N đóng.
export function pivots(bars, N) {
  const out = [];
  for (let i = N; i + N < bars.length; i++) {
    let hi = true, lo = true;
    for (let k = 1; k <= N; k++) {
      if (!(bars[i].h > bars[i - k].h && bars[i].h > bars[i + k].h)) hi = false;
      if (!(bars[i].l < bars[i - k].l && bars[i].l < bars[i + k].l)) lo = false;
    }
    if (hi && !lo) out.push({ i, high: true, price: bars[i].h, known_t: bars[i + N].close_t });
    if (lo && !hi) out.push({ i, high: false, price: bars[i].l, known_t: bars[i + N].close_t });
  }
  return out;
}

// Chỉ số M1 đầu tiên có t >= x.
export function idxAt(m, x) {
  let lo = 0, hi = m.n;
  while (lo < hi) { const mid = (lo + hi) >> 1; if (m.t[mid] < x) lo = mid + 1; else hi = mid; }
  return lo;
}

// Giá trị của chuỗi khung lớn đã biết tại thời điểm x (nến đã đóng gần nhất). Trả chỉ số nến, -1 nếu chưa có.
export function lastClosed(bars, x) {
  let lo = 0, hi = bars.length - 1, ans = -1;
  while (lo <= hi) { const mid = (lo + hi) >> 1; if (bars[mid].close_t <= x) { ans = mid; lo = mid + 1; } else hi = mid - 1; }
  return ans;
}

// ---------------------------------------------------------------- ngẫu nhiên có hạt giống
export function rng(seed) {
  let s = BigInt(seed) & 0xffffffffffffffffn;
  return () => { s = (s * 6364136223846793005n + 1442695040888963407n) & 0xffffffffffffffffn; return Number(s >> 11n) / 9007199254740992; };
}

// ---------------------------------------------------------------- đo phản ứng tại cản (SPEC 24.3, bản nghiên cứu)
// level: {id, side:+1 hỗ trợ/-1 kháng cự, lo, hi, known_t, expire_t, atr_src, tags:{...}}
// Cản giả: dời ngẫu nhiên (1..3)×max(bề rộng, atr_src), cùng thời gian, cùng nhãn (như công cụ MQL).
export function makeFakes(levels, seed = 20260929) {
  const r = rng(seed);
  return levels.map(L => {
    const w = L.hi - L.lo, unit = Math.max(w, L.atr_src || 0, 0.5);
    const off = (1 + 2 * r()) * unit * (r() < 0.5 ? -1 : 1);
    return { ...L, id: 'g' + L.id, lo: L.lo + off, hi: L.hi + off, fake: true };
  });
}

// Đi qua M1 cho từng cản: cần giá ở hẳn phía đúng (nến M1 nằm ngoài vùng) rồi mới tính chạm. Mỗi lần chạm: quãng bật xa nhất
// (từ nến M1 SAU nến chạm) khỏi mép gần trước khi nến M5 đóng qua mép xa thêm eps, hoặc hết `horizon` phút. Bị phá thì cản chết.
// `maxTouches`: số lần chạm tối đa đo cho mỗi cản.
export function probe(m, m5atr, m5bars, levels, { horizon = 240, maxTouches = 3, epsAtr = 0.1 } = {}) {
  const res = [];
  for (const L of levels) {
    let i = idxAt(m, L.known_t);
    const iEnd = Math.min(m.n, idxAt(m, L.expire_t));
    let armed = false, touches = 0;
    const near = L.side > 0 ? L.hi : L.lo, far = L.side > 0 ? L.lo : L.hi;
    while (i < iEnd && touches < maxTouches) {
      // chờ giá ở hẳn phía đúng
      if (!armed) { if ((L.side > 0 && m.l[i] > near) || (L.side < 0 && m.h[i] < near)) armed = true; i++; continue; }
      const hit = L.side > 0 ? m.l[i] <= near : m.h[i] >= near;
      if (!hit) { i++; continue; }
      const k5 = lastClosed(m5bars, m.t[i]);
      const a5 = k5 >= 0 ? m5atr[k5] : 0;
      if (!(a5 > 0)) { i++; continue; }
      const eps = epsAtr * a5;
      let best = 0, broken = false, j = i + 1;
      const jEnd = Math.min(iEnd, idxAt(m, m.t[i] + horizon * MIN));
      for (; j < jEnd; j++) {
        const ext = L.side > 0 ? m.h[j] - near : near - m.l[j];
        // nến M5 đóng ở phút cuối của khối 5 phút
        const isM5Close = ((m.t[j] / MIN + 1) % 5) === 0;
        if (isM5Close && ((L.side > 0 && m.c[j] < far - eps) || (L.side < 0 && m.c[j] > far + eps))) { broken = true; break; }
        if (ext > best) best = ext;
      }
      res.push({ id: L.id, fake: !!L.fake, touch_no: touches, t: m.t[i], bounce: best / a5, broken, tags: L.tags, width: Math.abs(L.hi - L.lo) });
      touches++;
      if (broken) break;
      armed = false; i = j;
    }
  }
  return res;
}

// Tổng hợp theo nhóm nhãn: % bật >= k ATR M5, % bị phá; so thật với giả, khoảng tin cậy 95% của hiệu (hai tỉ lệ).
export function summarize(rows, keyFn = () => 'tat_ca', k = 2) {
  const g = new Map();
  for (const r of rows) {
    const keys = [].concat(keyFn(r));
    for (const key of keys) {
      if (!g.has(key)) g.set(key, { key, n: [0, 0], hit: [0, 0], brk: [0, 0], sum: [0, 0] });
      const s = g.get(key), f = r.fake ? 1 : 0;
      s.n[f]++; if (r.bounce >= k) s.hit[f]++; if (r.broken) s.brk[f]++; s.sum[f] += Math.min(r.bounce, 10);
    }
  }
  const out = [];
  for (const s of g.values()) {
    const p1 = s.n[0] ? s.hit[0] / s.n[0] : NaN, p2 = s.n[1] ? s.hit[1] / s.n[1] : NaN;
    const se = Math.sqrt((p1 * (1 - p1)) / Math.max(1, s.n[0]) + (p2 * (1 - p2)) / Math.max(1, s.n[1]));
    out.push({ key: s.key, n_real: s.n[0], n_fake: s.n[1], bounce_real: +(100 * p1).toFixed(1), bounce_fake: +(100 * p2).toFixed(1),
      diff: +(100 * (p1 - p2)).toFixed(1), ci95: +(196 * se).toFixed(1), broken_real: +(100 * s.brk[0] / Math.max(1, s.n[0])).toFixed(1),
      broken_fake: +(100 * s.brk[1] / Math.max(1, s.n[1])).toFixed(1) });
  }
  return out.sort((a, b) => a.key < b.key ? -1 : 1);
}

// Số cản thật khác đang sống có dải chồng lên tại thời điểm chạm (đo độ nhiễu).
export function overlapStats(levels, rows) {
  const real = levels.filter(L => !L.fake);
  const counts = [];
  for (const r of rows) {
    if (r.fake) continue;
    const L = real.find(x => x.id === r.id);
    if (!L) continue;
    let c = 0;
    for (const o of real) {
      if (o === L || o.known_t > r.t || o.expire_t <= r.t) continue;
      if (o.lo <= L.hi && o.hi >= L.lo) c++;
    }
    counts.push(c);
  }
  counts.sort((a, b) => a - b);
  const q = p => counts.length ? counts[Math.floor(p * (counts.length - 1))] : NaN;
  return { n: counts.length, p10: q(0.1), p50: q(0.5), p90: q(0.9) };
}

// ---------------------------------------------------------------- mô phỏng lệnh có phí (SPEC 24.6)
// sig: {t (quyết định lúc t; vào ở giá mở nến M1 đầu tiên có t >= sig.t), dir, sl, tp, maxMin}
// Mua: vào Ask = bid + spread + trượt; dừng lỗ khớp ở mức − trượt; chốt lời khớp đúng mức (lệnh giới hạn).
// Dừng lỗ và chốt lời cùng một nến M1: tính dừng lỗ trước. Hết giờ: đóng ở giá đóng nến − trượt.
export function simulate(m, sigs, cost = COST) {
  const out = [];
  for (const s of sigs) {
    const i0 = idxAt(m, s.t);
    if (i0 >= m.n) continue;
    const buy = s.dir > 0;
    const entry = buy ? m.o[i0] + cost.spread + cost.slip : m.o[i0] - cost.slip;
    const risk = buy ? entry - s.sl : s.sl - entry;
    if (!(risk > 0)) continue;
    const iEnd = Math.min(m.n, idxAt(m, m.t[i0] + (s.maxMin || 480) * MIN));
    let exit = null, how = 'het_gio';
    for (let i = i0; i < iEnd; i++) {
      // giá thoát: mua thoát ở Bid; bán thoát ở Ask = bid + spread
      const lo = buy ? m.l[i] : m.l[i] + cost.spread, hi = buy ? m.h[i] : m.h[i] + cost.spread;
      const slHit = buy ? lo <= s.sl : hi >= s.sl;
      const tpHit = s.tp != null && (buy ? hi >= s.tp : lo <= s.tp);
      if (slHit) { exit = buy ? s.sl - cost.slip : s.sl + cost.slip; how = 'dung_lo'; break; }
      if (tpHit) { exit = s.tp; how = 'chot_loi'; break; }
    }
    if (exit === null) { const i = iEnd - 1; exit = buy ? m.c[i] - cost.slip : m.c[i] + cost.spread + cost.slip; }
    const R = (buy ? exit - entry : entry - exit) / risk;
    out.push({ ...s, entry, risk, exit, how, R });
  }
  return out;
}

export function statR(trs) {
  const n = trs.length;
  if (!n) return { n: 0 };
  const mean = trs.reduce((a, x) => a + x.R, 0) / n;
  const sd = Math.sqrt(trs.reduce((a, x) => a + (x.R - mean) ** 2, 0) / Math.max(1, n - 1));
  const win = trs.filter(x => x.R > 0).length / n;
  return { n, meanR: +mean.toFixed(3), ci95: +(1.96 * sd / Math.sqrt(n)).toFixed(3), win: +(100 * win).toFixed(1) };
}

// ---------------------------------------------------------------- v2 (29/09, sau kiểm toán): đối chứng công bằng
// Cản giả "cùng hình học": giữ khoảng cách có dấu từ giá lúc biết tới mép gần (theo ATR H1), cùng nửa bề rộng (theo ATR H1),
// cùng thứ trong tuần và giờ, dời ±1..3 tuần. Tuổi cố định `life` cho cả thật lẫn giả (không lấy theo sự kiện của cản thật).
export function makePlacebo(m, h1bars, h1atr, levels, seed, life) {
  const r = rng(seed), out = [];
  const t0 = m.t[0], t1 = m.t[m.n - 1];
  for (const L of levels) {
    const i = Math.min(m.n - 1, idxAt(m, L.known_t));
    const k = lastClosed(h1bars, L.known_t); const a = k >= 0 ? h1atr[k] : 0;
    if (!(a > 0)) continue;
    const px = m.c[Math.max(0, i - 1)];
    const near = L.side > 0 ? L.hi : L.lo;
    const dist = (near - px) / a, half = (L.hi - L.lo) / a;
    for (let tries = 0; tries < 6; tries++) {
      const wk = (1 + Math.floor(r() * 3)) * (r() < 0.5 ? -1 : 1);
      const t = L.known_t + wk * 7 * 86400000;
      if (t < t0 + 7 * 86400000 || t + life > t1) continue;
      const j = Math.min(m.n - 1, idxAt(m, t));
      const k2 = lastClosed(h1bars, t); const a2 = k2 >= 0 ? h1atr[k2] : 0;
      if (!(a2 > 0)) continue;
      const px2 = m.c[Math.max(0, j - 1)], near2 = px2 + dist * a2, w2 = half * a2;
      const lo = L.side > 0 ? near2 - w2 : near2, hi = L.side > 0 ? near2 : near2 + w2;
      out.push({ ...L, id: 'p' + seed + '_' + L.id, lo, hi, known_t: t, expire_t: t + life, fake: true });
      break;
    }
  }
  return out;
}

// Lệnh chờ đúng giá: s.limit = giá chờ; khớp khi giá chạm trong s.limitMin phút; nếu nến khớp cũng chạm dừng lỗ → thua.
export function simulateLimit(m, sigs, cost = COST) {
  const out = [];
  for (const s of sigs) {
    const buy = s.dir > 0;
    let i = idxAt(m, s.t);
    const iStop = Math.min(m.n, idxAt(m, s.t + (s.limitMin || 240) * MIN));
    let fill = -1;
    for (; i < iStop; i++) { if (buy ? m.l[i] + cost.spread <= s.limit : m.h[i] >= s.limit) { fill = i; break; } }
    if (fill < 0) continue;
    const entry = s.limit, risk = buy ? entry - s.sl : s.sl - entry;
    if (!(risk > 0)) continue;
    const iEnd = Math.min(m.n, idxAt(m, m.t[fill] + (s.maxMin || 480) * MIN));
    let exit = null, how = 'het_gio';
    for (let j = fill; j < iEnd; j++) {
      const lo = buy ? m.l[j] : m.l[j] + cost.spread, hi = buy ? m.h[j] : m.h[j] + cost.spread;
      const slHit = buy ? lo <= s.sl : hi >= s.sl;
      const tpHit = j > fill && s.tp != null && (buy ? hi >= s.tp : lo <= s.tp);
      if (slHit) { exit = buy ? s.sl - cost.slip : s.sl + cost.slip; how = 'dung_lo'; break; }
      if (tpHit) { exit = s.tp; how = 'chot_loi'; break; }
    }
    if (exit === null) { const j = iEnd - 1; exit = buy ? m.c[j] - cost.slip : m.c[j] + cost.spread + cost.slip; }
    out.push({ ...s, entry, risk, exit, how, R: (buy ? exit - entry : entry - exit) / risk, fill_t: m.t[fill] });
  }
  return out;
}
