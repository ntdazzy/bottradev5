// s411_strict_fixed.mjs (AUDIT: bản sửa nhìn trước nhỏ: khi dịch Z sang Z-1 sau khi đã xem Z+1, known_t phải >= lúc Z+1 đóng) — vùng Z "Secret of 411" làm CHẶT theo docs/research/02-secret-of-411-part1.md (mục 3–5, 8, 9).
// Mọi luật viết cho BÁN (hình M, cản trên). MUA đối xứng: làm cùng luật trên giá lật dấu (h' = -l, l' = -h, o' = -o, c' = -c).
//  1. Đỉnh/đáy: L.pivots(N) theo khung; dãy xoay xen kẽ (cùng loại liên tiếp thì giữ cái cực hơn). Xử lý theo thứ tự known_t.
//  2. Hình M: 4 điểm cuối A(đáy) – P1(đỉnh) – B(đáy) – P2(đỉnh), B > A, P1 > B, P2 > B.
//  3. Z = nến đầu tiên trong [P2-zWin, P2+zWin] có L[Z] < L[Z-1]; ISL = L[Z-1], cần L[Z] < ISL <= H[Z].
//  4. HSL: ≥ hslMin đầu râu của nến cũ (từ Z-hslW tới B-1) nằm trong [L[Z], H[Z]], thân nến đó nằm ngoài dải (râu chọc vào).
//     Không đạt thì dịch sang Z+1 rồi Z-1 (nến mới phải chứa ISL) — tài liệu tr. 7.
//  5. Nhấn chìm: chặt = nến sau đóng dưới L[Z]; lỏng = 1 trong 2 nến sau đóng dưới L[Z].
//  6. Phá B rồi A (râu tính, trên M1) sau đỉnh P2; nếu giá vượt H[Z] trước khi phá A thì bỏ.
//  7. Dùng được từ max(lúc biết Z + xác nhận, lúc nến M1 phá A đóng); phải còn FRESH (chưa chạm L[Z] từ lúc phá A).
//  8. Tùy chọn lọc hướng khung lớn: hướng = chiều của hình M/W phá đủ 2 mức gần nhất trên khung lớn (H1,M30→H4; H4→D1).
// Lệnh: chỉ lần chạm đầu. 'limit' = chạm mép gần thì vào (giả lập lệnh chờ: vào ở giá mở M1 sau nến chạm);
//       'm5rej' = nến M5 đóng quay lại ngoài mép gần trong rejWait nến M5. Dừng lỗ: trên H[Z] (+ đỉnh từ lúc chạm) + slBuf×ATR khung vùng.
//       Chốt lời: mép gần của vùng ngược chiều còn fresh gần nhất (khung ≤ khung vào) cách ≥ minRR; không có thì rr×R.
// LUẬT ĐÓNG BĂNG (ghi TRƯỚC khi chạy bất kỳ cấu hình nào qua runner, chỉ dựa trên đếm cản/bề rộng):
//  Giai đoạn 1 (bộ cản, lệnh mặc định limit + chốt vùng): A,B,C,D,E. Chọn bộ cản có (diff − ci95) nhóm tat_ca lớn nhất trong các bộ
//  có n_real ≥ 100 (không bộ nào đạt thì lấy bộ nhiều lần chạm nhất). Giai đoạn 2: trên bộ cản đó chạy F = m5rej+chốt vùng,
//  G = limit+2R, H = m5rej+2R. Đóng băng cấu hình (trong 4 cấu hình của bộ cản đã chọn) có meanR − random.meanR lớn nhất.
//  Mọi cấu hình có maxTouches=1 (chỉ lần chạm fresh đầu).
import * as L from '../lib.mjs';

const DEF = {
  tfs: ['H1', 'H4'], N: { M30: 3, H1: 3, H4: 2, D1: 2 }, zWin: 2, engulf: 'strict', hslW: 120, hslMin: 1, shift: true,
  lifeBars: 240, htf: false, entry: 'limit', tp: 'zone', rr: 2, minRR: 1, slBuf: 0.1, maxMin: 1440, rejWait: 6,
};
const HTF = { M30: 'H4', H1: 'H4', H4: 'D1' };
export const DBG = {}; const dbg = k => { DBG[k] = (DBG[k] || 0) + 1; };

// Hình M (s=-1) / W (s=+1) từ dãy đỉnh đáy xen kẽ. Mỗi hình biết lúc P2.known_t.
function patterns(bars, N) {
  const seq = [], pats = [];
  for (const p of L.pivots(bars, N)) {
    const last = seq[seq.length - 1];
    if (last && last.high === p.high) {
      if (p.high ? p.price > last.price : p.price < last.price) seq[seq.length - 1] = p; else continue;
    } else seq.push(p);
    if (seq.length < 4) continue;
    const [A, P1, B, P2] = seq.slice(-4);
    if (P2.high && B.price > A.price && P1.price > B.price && P2.price > B.price) pats.push({ s: -1, A, P1, B, P2 });
    if (!P2.high && B.price < A.price && P1.price < B.price && P2.price < B.price) pats.push({ s: 1, A, P1, B, P2 });
  }
  return pats;
}

// Truy cập giá trong "không gian bán": s=-1 giữ nguyên, s=+1 lật dấu.
const acc = s => s < 0
  ? { lo: b => b.l, hi: b => b.h, op: b => b.o, cl: b => b.c, px: x => x, mlo: (m, i) => m.l[i], mhi: (m, i) => m.h[i] }
  : { lo: b => -b.h, hi: b => -b.l, op: b => -b.o, cl: b => -b.c, px: x => -x, mlo: (m, i) => -m.h[i], mhi: (m, i) => -m.l[i] };

// Tìm lúc phá B rồi A trên M1, từ nến M1 tạo đỉnh P2. invFrom/invHi: sau mốc này, giá vượt invHi (không gian bán) thì hỏng.
function breakBA(m, a, P2bar, Bp, Ap, invFrom, invHi, tMax) {
  let iS = P2bar.i0, best = -Infinity;
  for (let i = P2bar.i0; i <= P2bar.i1; i++) if (a.mhi(m, i) > best) { best = a.mhi(m, i); iS = i; }
  let gotB = false;
  for (let i = iS; i < m.n && m.t[i] < tMax; i++) {
    if (m.t[i] >= invFrom && a.mhi(m, i) > invHi) return -1;
    if (!gotB && a.mlo(m, i) < Bp) gotB = true;
    if (gotB && a.mlo(m, i) < Ap) return i;
  }
  return -1;
}

function zonesFor(data, tfName, cfg) {
  const { m } = data, { bars, atr } = data.tf[tfName];
  const tfMs = L.TF[tfName] * L.MIN, out = [], seen = new Set();
  for (const P of patterns(bars, cfg.N[tfName])) {
    const { s, A, B, P2 } = P, a = acc(s);
    dbg(tfName + ' 0_M/W');
    // 3. Z và ISL
    let z = -1;
    for (let k = Math.max(B.i + 2, P2.i - cfg.zWin); k <= P2.i + cfg.zWin && k < bars.length; k++)
      if (a.lo(bars[k]) < a.lo(bars[k - 1])) { z = k; break; }
    if (z < 0) continue;
    dbg(tfName + ' 1_Z');
    const ISL = a.lo(bars[z - 1]);
    if (!(ISL <= a.hi(bars[z]))) continue;
    dbg(tfName + ' 2_ISL');
    // 4. HSL (+ dịch Z+1, Z-1)
    let zc = -1, hsl = 0, insp = z; // AUDIT FIX: nến cao nhất đã xem khi chọn Z (Z+1 được xem trước Z-1)
    for (const c of cfg.shift ? [z, z + 1, z - 1] : [z]) {
      if (c <= B.i || c >= bars.length) continue;
      insp = Math.max(insp, c);
      const lo = a.lo(bars[c]), hi = a.hi(bars[c]);
      if (!(lo <= ISL && ISL <= hi)) continue;
      let n = 0;
      for (let j = Math.max(0, c - cfg.hslW); j < B.i; j++) {
        const b = bars[j], bTop = Math.max(a.op(b), a.cl(b)), bBot = Math.min(a.op(b), a.cl(b));
        if (a.hi(b) >= lo && a.hi(b) <= hi && bTop < lo) n++;       // râu trên chọc vào, thân dưới dải
        else if (a.lo(b) >= lo && a.lo(b) <= hi && bBot > hi) n++;  // râu dưới chọc vào, thân trên dải
      }
      if (n >= cfg.hslMin) { zc = c; hsl = n; break; }
    }
    if (zc < 0) continue;
    dbg(tfName + ' 3_HSL');
    const Z = bars[zc], zlo = a.lo(Z), zhi = a.hi(Z);
    // 5. Nhấn chìm
    let ce = -1;
    if (zc + 1 < bars.length && a.cl(bars[zc + 1]) < zlo) ce = zc + 1;
    else if (cfg.engulf === 'loose' && zc + 2 < bars.length && a.cl(bars[zc + 2]) < zlo) ce = zc + 2;
    if (ce < 0) continue;
    dbg(tfName + ' 4_engulf');
    const E = bars[zc + 1];
    const eng = ce === zc + 2 ? 'hai_nen' : a.hi(E) < zlo ? 'gap' : a.cl(Z) > a.op(Z) ? (a.hi(E) > zhi ? 'perfect' : 'z_tang_khac') : (a.hi(E) < zhi ? 'dominant' : 'z_giam_khac');
    const key = s + ':' + zc;
    if (seen.has(key)) continue;
    const zKnown = Math.max(P2.known_t, bars[Math.max(ce, insp)].close_t); // AUDIT FIX: gồm cả nến Z+1 đã xem
    const tMax = zKnown + cfg.lifeBars * tfMs;
    // 6. Phá B rồi A
    const iA = breakBA(m, a, bars[P2.i], a.px(B.price), a.px(A.price), bars[ce].close_t, zhi, tMax);
    if (iA < 0) continue;
    dbg(tfName + ' 5_breakBA');
    const known_t = Math.max(zKnown, m.t[iA] + L.MIN);
    // 7. Fresh: không chạm L[Z] từ sau nến phá A tới lúc dùng được
    const iK = L.idxAt(m, known_t);
    let fresh = true;
    for (let i = iA + 1; i < iK; i++) if (a.mhi(m, i) >= zlo) { fresh = false; break; }
    if (!fresh) continue;
    dbg(tfName + ' 6_fresh');
    seen.add(key);
    const expire_t = known_t + cfg.lifeBars * tfMs;
    // lần chạm đầu (để biết vùng còn fresh khi làm chốt lời; chỉ dùng để so "đã chạm trước t chưa")
    let touch_t = Infinity;
    for (let i = iK; i < m.n && m.t[i] < expire_t; i++) if (a.mhi(m, i) >= zlo) { touch_t = m.t[i]; break; }
    const lo = s < 0 ? zlo : -zhi, hi = s < 0 ? zhi : -zlo;
    out.push({ id: `${tfName}${zc}${s < 0 ? 's' : 'b'}`, side: s, lo, hi, known_t, expire_t, atr_src: atr[zc],
      tags: { tf: tfName, eng, hsl: hsl >= 3 ? '3+' : String(hsl) },
      _s: s, _tf: tfName, _tfMin: L.TF[tfName], _touch_t: touch_t, _atr: atr[zc] });
  }
  return out;
}

// Hướng khung lớn: chuỗi (thời điểm phá A đóng, chiều) của mọi hình M/W phá đủ 2 mức.
function htfDir(data, tfName, cfg) {
  const { m } = data, { bars } = data.tf[tfName], ev = [];
  for (const P of patterns(bars, cfg.N[tfName] ?? 2)) {
    const a = acc(P.s), P2b = bars[P.P2.i];
    const iA = breakBA(m, a, P2b, a.px(P.B.price), a.px(P.A.price), P2b.close_t, a.px(P.P2.price), P2b.close_t + 200 * L.TF[tfName] * L.MIN);
    if (iA < 0) continue;
    ev.push({ t: Math.max(P.P2.known_t, m.t[iA] + L.MIN), s: P.s });
  }
  ev.sort((x, y) => x.t - y.t);
  return t => { let lo = 0, hi = ev.length - 1, ans = 0; while (lo <= hi) { const md = (lo + hi) >> 1; if (ev[md].t <= t) { ans = ev[md].s; lo = md + 1; } else hi = md - 1; } return ans; };
}

export function levels(data, cfg0 = {}) {
  const cfg = { ...DEF, ...cfg0, N: { ...DEF.N, ...(cfg0.N || {}) } };
  let out = [];
  for (const tf of cfg.tfs) {
    let z = zonesFor(data, tf, cfg);
    if (cfg.htf) {
      const dir = htfDir(data, HTF[tf], cfg);
      // vùng bán (s=-1) cần hướng khung lớn giảm (hình M gần nhất, s=-1)
      z = z.filter(x => dir(x.known_t) === x._s);
    }
    out = out.concat(z);
  }
  return out;
}

export function signals(data, levels, cfg0 = {}) {
  const cfg = { ...DEF, ...cfg0 };
  const { m } = data, { bars: m5 } = data.tf.M5;
  const sigs = [];
  for (const Lv of levels) {
    if (!(Lv._touch_t < Lv.expire_t)) continue;
    const s = Lv._s, a = acc(s), zlo = s < 0 ? Lv.lo : -Lv.hi, zhi = s < 0 ? Lv.hi : -Lv.lo;
    const buf = cfg.slBuf * Lv._atr, iT = L.idxAt(m, Lv._touch_t);
    let t, entrySell, slSell;
    if (cfg.entry === 'limit') {
      t = m.t[iT] + L.MIN; entrySell = zlo; slSell = zhi + buf;
    } else {
      // m5rej: nến M5 chứa lần chạm và tối đa rejWait nến sau
      let k = L.lastClosed(m5, m.t[iT]) + 1, mx = -Infinity, done = false;
      for (let w = 0; w < cfg.rejWait && k < m5.length && !done; w++, k++) {
        const b = m5[k];
        mx = Math.max(mx, a.hi(b));
        if (a.cl(b) > zhi) done = true; // đóng qua mép xa: vùng hỏng
        else if (a.cl(b) < zlo) { t = b.close_t; entrySell = a.cl(b); slSell = Math.max(zhi, mx) + buf; done = true; }
      }
      if (t === undefined) continue;
    }
    const risk = slSell - entrySell;
    if (!(risk > 0)) continue;
    // chốt lời: vùng ngược chiều còn fresh, khung ≤ khung vào, mép gần cách ≥ minRR·R
    let tpSell = null, tpTag = 'rr';
    if (cfg.tp === 'zone') {
      for (const o of levels) {
        if (o._s !== -s || o._tfMin > Lv._tfMin || o.known_t > t || o._touch_t <= t || o.expire_t <= t) continue;
        const near = s < 0 ? o.hi : -o.lo; // mép gần của vùng ngược chiều, trong không gian bán
        if (near <= entrySell - cfg.minRR * risk && (tpSell === null || near > tpSell)) { tpSell = near; tpTag = 'zone'; }
      }
    }
    if (tpSell === null) tpSell = entrySell - cfg.rr * risk;
    const back = x => s < 0 ? x : -x;
    sigs.push({ t, dir: s < 0 ? -1 : 1, sl: back(slSell), tp: back(tpSell), maxMin: cfg.maxMin, entry_ref: back(entrySell),
      tags: { ...Lv.tags, tp: tpTag } });
  }
  return sigs;
}
