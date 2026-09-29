// break_go — "phá rồi đi" (Osler 2003: lệnh dừng cụm ngay sau số tròn và đỉnh/đáy dễ thấy; giá vượt qua → kích hoạt dừng → đi tiếp).
//
// CẢN (đỉnh = kháng cự side −1, đáy = hỗ trợ side +1; cản là ĐƯỜNG lo = hi = giá; atr_src = ATR H1 đã đóng lúc known_t):
//   R100/R50: bội số $100 / bội số $50 không phải $100. R10: bội số $10 không phải $50 (thử RIÊNG, cấu hình C8).
//     Tạo mỗi ngày UTC lúc 00:00 cho các số tròn trong ±roundAtr×ATR D1 (nến D1 đã đóng) quanh giá đóng M1 cuối trước 00:00;
//     mỗi số tạo HAI bản (kháng cự và hỗ trợ) để bắt phá theo cả hai chiều; sống tới 24:00 ngày đó.
//   PD: đỉnh/đáy ngày đủ phiên gần nhất (≥ 600 nến M1), biết lúc ngày đó đóng, sống tới lúc ngày đủ phiên kế tiếp đóng
//       (trong dữ liệu bị cắt chưa có ngày kế tiếp → sống tới hết dữ liệu; nhân quả: ngày đủ phiên chỉ biết khi nó đóng).
//   PW: đỉnh/đáy tuần trước (tuần bắt đầu CN 00:00 UTC), biết lúc tuần đóng, sống tới hết tuần sau.
//   AS: biên phiên Á 00:00–07:00 UTC (≥ 300 nến M1), biết lúc 07:00, sống tới 24:00.
//   SW: đỉnh/đáy fractal H1 N=3 và H4 N=2, là cực trị của ≥ 20 nến bên trái; biết lúc nến xác nhận thứ N đóng; sống 120 giờ.
//
// LỆNH: với mỗi cản, sau known_t phải có một nến (M5 hoặc M1 tùy `entry`) nằm hẳn phía đúng (chưa chạm cản) → "sẵn sàng";
//   rồi nến ĐẦU TIÊN đóng vượt cản ≥ k×ATR5 (ATR M5 của nến M5 đã đóng trước nến đang xét) → vào theo chiều phá, lúc nến đó đóng.
//   Mỗi cản tối đa 1 lệnh. Dừng lỗ thô = cản − chiều×slBuf×ATR15 (ATR M15 đã đóng lúc quyết định); rủi ro = max(thô,
//   minRiskAtr×ATR15, minRiskUsd). Chốt lời = rr×rủi ro tính từ giá đóng nến phá (rr = 0 → không chốt, thoát theo giờ maxMin).
//   Bỏ lệnh 20:00–24:00 UTC (thanh khoản mỏng, phí mô hình không sát). Bỏ tin: không vào trong ±5 phút quanh 12:30 và 13:30 UTC
//   (tin Mỹ 8:30 giờ New York rơi vào 12:30 UTC mùa hè, 13:30 UTC mùa đông).
//   Trùng giờ và chiều (hai cản cùng giá) → giữ một, ưu tiên PW > PD > AS > SW > R100 > R50 > R10.
//   Nhãn: lv (loại cản), ses (lo 07–12, ny 12–17, ot còn lại), dir (mua/ban), fb (y = lệnh đầu tiên trong ngày UTC, n = không).
//
// KẾ HOẠCH 8 CẤU HÌNH (ghi trước khi chạy; mọi cấu hình chạy với "_life_h":24 cho phần đo cản của runner2):
//   C1 mặc định: types R100,R50,PD,PW,AS,SW; entry M5; k 0.1; slBuf 0.5; minRiskAtr 1; rr 2; maxMin 240
//   C2 = C1 + k 0.3            C3 = C1 + entry M1            C4 = C1 + minRiskAtr 0, minRiskUsd 10
//   C5 = C1 + rr 1.5           C6 = C1 + rr 3                C7 = C1 + rr 0, maxMin 60 (chỉ thoát theo giờ 60 phút)
//   C8 = C1 + types [R10] (số tròn $10 riêng)
//   Lọc phiên và "lần phá đầu tiên trong ngày" chỉ báo theo nhãn (ses, fb), không phải cấu hình riêng.
// LUẬT ĐÓNG BĂNG (ghi trước khi xem kết quả lệnh):
//   Trong các cấu hình có ≥ 200 lệnh, chọn cấu hình có (meanR − meanR đối chứng CÙNG CHIỀU khớp giờ trong ngày) lớn nhất.
//   Nếu hai cấu hình đầu cách nhau < 0,02R → chọn cái ít thay đổi hơn so với C1 (C1 thắng nếu nằm trong hai cái đầu; hòa → số nhỏ hơn).
//   Sau đó chấm cấu hình đóng băng theo ngưỡng đạt: meanR > 0; hơn đối chứng cùng chiều > tổng hai ci95; n ≥ 200;
//   bỏ 3 lệnh lời nhất vẫn > 0; cả 03–07/2025 và 08–12/2025 đều > 0.
import * as L from '../lib.mjs';

const DEF = { types: ['R100', 'R50', 'PD', 'PW', 'AS', 'SW'], entry: 'M5', k: 0.1, slBuf: 0.5, minRiskAtr: 1, minRiskUsd: 0,
  rr: 2, maxMin: 240, noEntryFromH: 20, news: true, roundAtr: 3, fullDay: 600, swLeft: 20, swLife_h: 120 };
const cfgOf = cfg => ({ ...DEF, ...cfg });
const PRIO = { PW: 0, PD: 1, AS: 2, SW: 3, R100: 4, R50: 5, R10: 6 };
const DAY = 86400000, HOUR = 3600000;

export function levels(data, cfg = {}) {
  const c = cfgOf(cfg), { m } = data, h1 = data.tf.H1;
  const out = [];
  const add = (lv, side, price, known_t, expire_t, key, extra = {}) => {
    if (!c.types.includes(lv) || !(expire_t > known_t)) return;
    const k = L.lastClosed(h1.bars, known_t), aH1 = k >= 0 ? h1.atr[k] : 0;
    out.push({ id: lv + (side > 0 ? 'S' : 'R') + key, side, lo: price, hi: price, known_t, expire_t, atr_src: aH1,
      tags: { lv }, lv, price, ...extra });
  };
  const D1 = data.tf.D1.bars, W1 = data.tf.W1.bars;
  // PD: ngày đủ phiên (đã đóng), sống tới lúc ngày đủ phiên kế tiếp đóng.
  const full = D1.filter(b => b.close_t <= m.t[m.n - 1] + L.MIN && b.i1 - b.i0 + 1 >= c.fullDay);
  for (let d = 0; d < full.length; d++) {
    const P = full[d], exp = d + 1 < full.length ? full[d + 1].close_t : Infinity;
    add('PD', -1, P.h, P.close_t, exp, P.t);
    add('PD', 1, P.l, P.close_t, exp, P.t);
  }
  for (let w = 0; w + 1 < W1.length; w++) {
    const P = W1[w], W = W1[w + 1];
    if (P.close_t > m.t[m.n - 1] + L.MIN) continue;
    add('PW', -1, P.h, P.close_t, W.close_t, P.t);
    add('PW', 1, P.l, P.close_t, W.close_t, P.t);
  }
  for (const D of D1) {
    const t0 = D.t, t1 = D.t + 7 * HOUR;
    let h = -Infinity, l = Infinity, n = 0, i = L.idxAt(m, t0);
    for (; i < m.n && m.t[i] < t1; i++) { if (m.h[i] > h) h = m.h[i]; if (m.l[i] < l) l = m.l[i]; n++; }
    if (n < 300 || i >= m.n) continue;           // cần có dữ liệu tới 07:00 (bản cắt trước 07:00 → chưa biết)
    add('AS', -1, h, t1, D.t + DAY, D.t);
    add('AS', 1, l, t1, D.t + DAY, D.t);
  }
  // Đỉnh/đáy H1 (N=3) và H4 (N=2), cực trị của ≥ swLeft nến bên trái.
  for (const [tfk, N] of [['H1', 3], ['H4', 2]]) {
    const bars = data.tf[tfk].bars;
    for (const p of L.pivots(bars, N)) {
      if (p.i < c.swLeft || p.known_t > m.t[m.n - 1] + L.MIN) continue;
      let ok = true;
      for (let q = p.i - c.swLeft; q < p.i && ok; q++) if (p.high ? bars[q].h >= p.price : bars[q].l <= p.price) ok = false;
      if (!ok) continue;
      add('SW', p.high ? -1 : 1, p.price, p.known_t, p.known_t + c.swLife_h * HOUR, tfk + bars[p.i].t, { src: tfk });
    }
  }
  // Số tròn: mỗi ngày lúc 00:00 UTC.
  const rt = ['R100', 'R50', 'R10'].filter(x => c.types.includes(x));
  if (rt.length) {
    const step = rt.includes('R10') ? 10 : 50;
    for (const D of D1) {
      const i = L.idxAt(m, D.t);
      if (i < 1) continue;
      const px = m.c[i - 1], kd = L.lastClosed(D1, D.t), aD = kd >= 0 ? data.tf.D1.atr[kd] : 0;
      if (!(aD > 0)) continue;
      const lo = Math.ceil((px - c.roundAtr * aD) / step) * step, hi = px + c.roundAtr * aD;
      for (let p = lo; p <= hi; p += step) {
        const lv = p % 100 === 0 ? 'R100' : p % 50 === 0 ? 'R50' : 'R10';
        if (!c.types.includes(lv)) continue;
        add(lv, -1, p, D.t, D.t + DAY, D.t + '_' + p);
        add(lv, 1, p, D.t, D.t + DAY, D.t + '_' + p);
      }
    }
  }
  return out;
}

const sesOf = t => { const h = new Date(t).getUTCHours(); return h >= 7 && h < 12 ? 'lo' : h >= 12 && h < 17 ? 'ny' : 'ot'; };
const newsBlock = t => { const md = (t % DAY) / 60000; return Math.abs(md - 750) <= 5 || Math.abs(md - 810) <= 5; };

export function signals(data, levels, cfg = {}) {
  const c = cfgOf(cfg), { m } = data;
  const { bars: m5, atr: a5 } = data.tf.M5;
  const { bars: m15, atr: a15 } = data.tf.M15;
  const raw = [];
  const emit = (Lv, t, dir, entry) => {
    if (new Date(t).getUTCHours() >= c.noEntryFromH) return;
    if (c.news && newsBlock(t)) return;
    const j = L.lastClosed(m15, t), A15 = j >= 0 ? a15[j] : 0;
    if (!(A15 > 0)) return;
    const slRaw = Lv.price - dir * c.slBuf * A15;
    const risk = Math.max(dir * (entry - slRaw), c.minRiskAtr * A15, c.minRiskUsd);
    if (!(risk > 0)) return;
    raw.push({ t, dir, sl: entry - dir * risk, tp: c.rr > 0 ? entry + dir * c.rr * risk : null, maxMin: c.maxMin, entry_ref: entry,
      prio: PRIO[Lv.lv], tags: { lv: Lv.lv, ses: sesOf(t), dir: dir > 0 ? 'mua' : 'ban' } });
  };
  for (const Lv of levels) {
    const P = Lv.price, o = -Lv.side;               // o: chiều phá
    let armed = false;
    if (c.entry === 'M5') {
      for (let k = Math.max(1, L.lastClosed(m5, Lv.known_t) + 1); k < m5.length && m5[k].close_t <= Lv.expire_t; k++) {
        const b = m5[k], atr = a5[k - 1];
        if (b.close_t > m.t[m.n - 1] + L.MIN) break;  // nến chưa đóng trong dữ liệu
        const ext = o > 0 ? b.h : b.l;
        if (!armed) { if (o * (ext - P) < 0) armed = true; continue; }
        if (atr > 0 && o * (b.c - P) >= c.k * atr) { emit(Lv, b.close_t, o, b.c); break; }
      }
    } else {
      for (let i = L.idxAt(m, Lv.known_t); i < m.n && m.t[i] + L.MIN <= Lv.expire_t; i++) {
        const ext = o > 0 ? m.h[i] : m.l[i], tc = m.t[i] + L.MIN;
        if (!armed) { if (o * (ext - P) < 0) armed = true; continue; }
        const k5 = L.lastClosed(m5, m.t[i]), atr = k5 >= 0 ? a5[k5] : 0;   // ATR M5 đã đóng trước nến M1 này
        if (atr > 0 && o * (m.c[i] - P) >= c.k * atr) { emit(Lv, tc, o, m.c[i]); break; }
      }
    }
  }
  raw.sort((a, b) => a.t - b.t || a.prio - b.prio);
  const seen = new Set(), sigs = [], firstDay = new Set();
  for (const x of raw) {
    const key = x.t + ':' + x.dir; if (seen.has(key)) continue; seen.add(key); delete x.prio;
    const d = Math.floor(x.t / DAY); x.tags.fb = firstDay.has(d) ? 'n' : 'y'; firstDay.add(d);
    sigs.push(x);
  }
  return sigs;
}
