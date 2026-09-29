// trend_pullback — xu hướng khung lớn (D1/H4) + hồi về vùng của nhịp đẩy cuối, chỉ theo chiều xu hướng.
//
// XU HƯỚNG (tham số cố định, kiểu sách giáo khoa), tính trên nến ĐÃ ĐÓNG tại thời điểm quyết định t:
//   lên  = đóng cửa D1 cuối > EMA50(D1)  VÀ  EMA20(H4) > EMA50(H4)
//   xuống = đóng cửa D1 cuối < EMA50(D1)  VÀ  EMA20(H4) < EMA50(H4); còn lại = không xu hướng (không vào lệnh).
//   cfg.trend='off' (chỉ để chẩn đoán): bỏ lọc, nhận cả hai chiều.
// VÙNG (cfg.lvl):
//   'fib' (mặc định): khi một đỉnh fractal khung cfg.tf (H4 N=2, H1 N=3) được xác nhận (known_t) và xu hướng đang lên:
//     nhịp đẩy = từ đáy thấp nhất (Lo) kể từ đáy fractal gần nhất trước đỉnh, tới đỉnh cao nhất (H) đoạn đó.
//     Vùng hỗ trợ = [H − 0,618·(H−Lo), H − 0,382·(H−Lo)]; gốc (origin) = Lo; đích swing = H. Xu hướng xuống: đối xứng từ đáy fractal.
//   'swing': đáy fractal cao hơn đáy fractal trước (higher low) khi xu hướng lên → vùng = râu dưới nến đáy [L, min(O,C)], gốc = L.
//     (đối xứng: đỉnh thấp hơn khi xu hướng xuống). Đích swing không định nghĩa → luôn 2R.
//   Vùng sống từ known_t tới: vùng mới cùng chiều được biết, hoặc 10 ngày, hoặc nến quyết định đóng qua gốc, hoặc đã ra 1 lệnh.
// VÀO LỆNH (cfg.entry):
//   'H1' (mặc định) / 'M15': nến quyết định đầu tiên (mở sau known_t) có râu chạm vùng (mua: L <= mép trên), đóng cùng màu với lệnh
//     (mua: C > O), đóng không thấp hơn mép dưới vùng (mua: C >= lo), và xu hướng tại lúc đóng vẫn đúng chiều → vào giá mở M1 kế tiếp.
//   'limit': lúc known_t (xu hướng đúng chiều, giá hiện tại chưa tới) đặt lệnh chờ ở mức 50% nhịp đẩy, chờ tối đa 3 ngày (lib.simulateLimit).
// DỪNG LỖ: mua = min(gốc, đáy thấp nhất từ known_t) − 0,2·ATR14(H4); bán = max(...) + 0,2·ATR14(H4) + spread.
//   Bắt buộc rủi ro (giá tham chiếu − dừng lỗ) >= 15 USD; chưa đủ thì bỏ nến đó, xét tiếp nến sau.
// CHỐT LỜI (cfg.tp): '2R' (mặc định) | '3R' | 'swing' = đỉnh H (mua) / đáy Lo (bán) của nhịp đẩy (bỏ lệnh nếu giá đã qua đích).
// GIỮ TỐI ĐA: 5 ngày lịch (maxMin = 7200).
// NHÃN: dir (buy/sell), tf, tp, lvl, vao.
//
// KẾ HOẠCH (định trước khi chạy runner, tối đa 8 cấu hình, chỉ discovery):
//   C1 {} (fib, H4, vào H1, 2R) | C2 {"tp":"3R"} | C3 {"tp":"swing"} | C4 {"entry":"M15"} | C5 {"tf":"H1"} | C6 {"lvl":"swing"}
//   C7 {"entry":"limit"} | C8 {"trend":"off"} (chẩn đoán giá trị của lọc xu hướng, KHÔNG được chọn đóng băng).
//   LUẬT ĐÓNG BĂNG (định trước): trong C1–C7 có >= 100 lệnh khớp, chọn cấu hình có (meanR − meanR đối chứng CÙNG CHIỀU) lớn nhất;
//   chênh < 0,02R thì lấy số cấu hình nhỏ hơn. Không cấu hình nào đủ 100 lệnh → đóng băng C1.
//   ĐẠT nếu cấu hình đóng băng: n >= 100, meanR > 0, và meanR − đối chứng cùng chiều > tổng hai ci95.
import * as L from '../lib.mjs';

const DAY = 86400000, MIN = L.MIN;
const PIV_N = { H1: 3, H4: 2 };

function ema(bars, n) {
  const a = new Float64Array(bars.length), k = 2 / (n + 1);
  let v = 0;
  for (let i = 0; i < bars.length; i++) { v = i === 0 ? bars[i].c : v + k * (bars[i].c - v); a[i] = v; }
  return a;
}

function trendFn(data, cfg) {
  if (cfg.trend === 'off') return () => 2; // 2 = nhận cả hai chiều
  const D = data.tf.D1.bars, H = data.tf.H4.bars;
  const ed = ema(D, 50), e20 = ema(H, 20), e50 = ema(H, 50);
  return t => {
    const kd = L.lastClosed(D, t), kh = L.lastClosed(H, t);
    if (kd < 49 || kh < 49) return 0;
    const up = D[kd].c > ed[kd] && e20[kh] > e50[kh], dn = D[kd].c < ed[kd] && e20[kh] < e50[kh];
    return up ? 1 : dn ? -1 : 0;
  };
}
const ok = (tr, dir) => tr === 2 || tr === dir;

export function levels(data, cfg = {}) {
  const tf = cfg.tf ?? 'H4', lvl = cfg.lvl ?? 'fib', N = PIV_N[tf];
  const bars = data.tf[tf].bars, h1 = data.tf.H1;
  const trend = trendFn(data, cfg);
  const piv = L.pivots(bars, N);
  const out = [];
  let lastHi = null, lastLo = null;
  for (const p of piv) {
    const prevOpp = p.high ? lastLo : lastHi, prevSame = p.high ? lastHi : lastLo;
    if (p.high) lastHi = p; else lastLo = p;
    const tr = trend(p.known_t);
    const k1 = L.lastClosed(h1.bars, p.known_t), a1 = k1 >= 0 ? h1.atr[k1] : 0;
    if (lvl === 'fib') {
      if (!prevOpp) continue;
      const dir = p.high ? 1 : -1;               // đỉnh mới xác nhận → nhịp lên → vùng hỗ trợ (mua)
      if (!ok(tr, dir)) continue;
      let hi = -Infinity, lo = Infinity;
      for (let j = prevOpp.i; j <= p.i; j++) { hi = Math.max(hi, bars[j].h); lo = Math.min(lo, bars[j].l); }
      const imp = hi - lo;
      if (!(imp > 0)) continue;
      const z = dir > 0 ? [hi - 0.618 * imp, hi - 0.382 * imp] : [lo + 0.382 * imp, lo + 0.618 * imp];
      out.push({ id: `${tf}_${p.i}${p.high ? 'h' : 'l'}`, side: dir, lo: z[0], hi: z[1], known_t: p.known_t,
        expire_t: p.known_t + 10 * DAY, atr_src: a1, origin: dir > 0 ? lo : hi, target: dir > 0 ? hi : lo, mid: (hi + lo) / 2,
        tags: { dir: dir > 0 ? 'buy' : 'sell', tf, lvl } });
    } else {
      const dir = p.high ? -1 : 1;               // đáy cao hơn → hỗ trợ (mua); đỉnh thấp hơn → kháng cự (bán)
      if (!prevSame || !ok(tr, dir)) continue;
      if (dir > 0 ? !(p.price > prevSame.price) : !(p.price < prevSame.price)) continue;
      const b = bars[p.i], body = dir > 0 ? Math.min(b.o, b.c) : Math.max(b.o, b.c);
      out.push({ id: `${tf}_${p.i}${p.high ? 'h' : 'l'}`, side: dir, lo: Math.min(p.price, body), hi: Math.max(p.price, body),
        known_t: p.known_t, expire_t: p.known_t + 10 * DAY, atr_src: a1, origin: p.price, target: null, mid: null,
        tags: { dir: dir > 0 ? 'buy' : 'sell', tf, lvl } });
    }
  }
  // vùng mới cùng chiều thay vùng cũ từ lúc được biết
  for (const s of [1, -1]) {
    const g = out.filter(z => z.side === s).sort((a, b) => a.known_t - b.known_t);
    for (let i = 0; i + 1 < g.length; i++) g[i].expire_t = Math.min(g[i].expire_t, g[i + 1].known_t);
  }
  return out.filter(z => z.expire_t > z.known_t);
}

export function signals(data, levels, cfg = {}) {
  const m = data.m, entry = cfg.entry ?? 'H1', tpMode = cfg.tp ?? '2R', maxMin = cfg.maxMin ?? 7200, minRisk = cfg.minRisk ?? 15;
  const SPREAD = L.COST.spread, H4 = data.tf.H4;
  const trend = trendFn(data, cfg);
  const bufAt = t => { const k = L.lastClosed(H4.bars, t); return k >= 0 ? 0.2 * H4.atr[k] : NaN; };
  const tpOf = (z, e, r) => tpMode === '3R' ? e + z.side * 3 * r : tpMode === 'swing' ? z.target : e + z.side * 2 * r;
  const sigs = [];
  for (const z of levels) {
    const s = z.side, tags = { ...z.tags, tp: tpMode, vao: entry };
    if (tpMode === 'swing' && z.target == null) continue;
    if (entry === 'limit') {
      if (z.mid == null) continue;
      const i = L.idxAt(m, z.known_t); if (i <= 0) continue;
      const px = m.c[i - 1], lim = z.mid, buf = bufAt(z.known_t);
      if (s > 0 ? px <= lim : px >= lim) continue;        // giá đã qua mức chờ: bỏ
      const sl = s > 0 ? z.origin - buf : z.origin + buf + SPREAD, r = Math.abs(lim - sl);
      if (!(r >= minRisk)) continue;
      const tp = tpOf(z, lim, r);
      if (s > 0 ? !(tp > lim) : !(tp < lim)) continue;
      sigs.push({ t: z.known_t, dir: s, sl, tp, limit: lim, limitMin: Math.min(3 * DAY, z.expire_t - z.known_t) / MIN, maxMin,
        entry_ref: lim, tags });
      continue;
    }
    const bars = data.tf[entry].bars;
    let k = L.lastClosed(bars, z.known_t) + 1, ext = s > 0 ? Infinity : -Infinity;
    for (; k < bars.length && bars[k].close_t <= z.expire_t; k++) {
      const b = bars[k];
      ext = s > 0 ? Math.min(ext, b.l) : Math.max(ext, b.h);
      if (s > 0 ? b.c < z.origin : b.c > z.origin) break;  // đóng qua gốc: vùng chết
      const touch = s > 0 ? b.l <= z.hi : b.h >= z.lo;
      const rej = s > 0 ? b.c > b.o && b.c >= z.lo : b.c < b.o && b.c <= z.hi;
      if (!touch || !rej || !ok(trend(b.close_t), s)) continue;
      const buf = bufAt(b.close_t);
      const sl = s > 0 ? Math.min(z.origin, ext) - buf : Math.max(z.origin, ext) + buf + SPREAD, r = Math.abs(b.c - sl);
      if (!(r >= minRisk)) continue;
      const tp = tpOf(z, b.c, r);
      if (s > 0 ? !(tp > b.c) : !(tp < b.c)) continue;
      sigs.push({ t: b.close_t, dir: s, sl, tp, maxMin, entry_ref: b.c, tags });
      break;
    }
  }
  return sigs.sort((a, b) => a.t - b.t);
}
