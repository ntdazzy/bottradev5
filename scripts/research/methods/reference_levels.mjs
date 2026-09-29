// reference_levels — cản tham chiếu ai cũng nhìn: đỉnh/đáy ngày trước (PD, ngày UTC đủ phiên), đỉnh/đáy tuần trước (PW),
// biên phiên Á 00:00–07:00 UTC (AS, biết lúc 07:00), biên giờ mở London 07:00–08:00 (LO, biết lúc 08:00).
// Cản là ĐƯỜNG (lo = hi = giá); hw > 0 cho vùng giá ± hw·ATR H1 (chỉ ảnh hưởng đo phản ứng/chồng; lệnh vẫn theo đường giá). Đỉnh = kháng cự (side −1), đáy = hỗ trợ (side +1). Cản giả dời theo atr_src = ATR H1 lúc known_t.
// Lệnh 3 nhóm tách riêng (nhãn sch): bounce (bật ở lần chạm đầu), break (nến M5 đóng vượt ≥ brThr·ATR5), sweep (quét qua ≥ swX·ATR5
// rồi nến M5 đóng quay lại trong swN nến). ATR5 dùng cho ngưỡng/đệm = ATR M5 của nến đã đóng TRƯỚC nến đang xét.
// Rủi ro tối thiểu = minRisk × ATR M15 (nến M15 đã đóng lúc quyết định). Chốt lời = rr × rủi ro. Không vào lệnh 20:00–24:00 UTC.
import * as L from '../lib.mjs';

const DEF = { types: ['PD', 'PW', 'AS', 'LO'], schemes: ['bounce', 'break', 'sweep'], rr: 1.5, bBuf: 0.3, brThr: 0.2, brBuf: 0.5,
  swX: 0.3, swN: 3, swBuf: 0.3, minRisk: 1.0, maxMin: 480, fullDay: 600, noEntryFromH: 20, hw: 0, zb: false };
const cfgOf = cfg => ({ ...DEF, ...cfg });
const PRIO = { PW: 0, PD: 1, AS: 2, LO: 3 };

export function levels(data, cfg = {}) {
  const c = cfgOf(cfg), { m } = data;
  const h1 = data.tf.H1;
  const out = [];
  const add = (cls, hl, price, known_t, expire_t, key) => {
    if (!c.types.includes(cls) || !(expire_t > known_t)) return;
    // Giá lúc known_t luôn nằm trong khung định nghĩa (đỉnh ≥ giá ≥ đáy) nên đỉnh = kháng cự, đáy = hỗ trợ.
    const side = hl === 'H' ? -1 : 1;
    const k = L.lastClosed(h1.bars, known_t), aH1 = k >= 0 ? h1.atr[k] : 0, w = c.hw * aH1;
    out.push({ id: cls + hl + key, side, lo: price - w, hi: price + w, known_t, expire_t, atr_src: aH1,
      tags: { cls, hl }, cls, price });
  };
  // Ngày đủ phiên (bỏ phiên Chủ nhật ngắn, ngày lễ)
  const D1 = data.tf.D1.bars.filter(b => b.i1 - b.i0 + 1 >= c.fullDay);
  for (let d = 1; d < D1.length; d++) {
    const P = D1[d - 1], D = D1[d];
    add('PD', 'H', P.h, P.close_t, D.close_t, P.t);
    add('PD', 'L', P.l, P.close_t, D.close_t, P.t);
  }
  const W1 = data.tf.W1.bars;
  for (let w = 1; w < W1.length; w++) {
    const P = W1[w - 1], W = W1[w];
    add('PW', 'H', P.h, P.close_t, W.close_t, P.t);
    add('PW', 'L', P.l, P.close_t, W.close_t, P.t);
  }
  for (const D of D1) {
    for (const [cls, a, b, minBars] of [['AS', 0, 7, 300], ['LO', 7, 8, 45]]) {
      const t0 = D.t + a * 3600000, t1 = D.t + b * 3600000;
      let h = -Infinity, l = Infinity, n = 0;
      for (let i = L.idxAt(m, t0); i < m.n && m.t[i] < t1; i++) { if (m.h[i] > h) h = m.h[i]; if (m.l[i] < l) l = m.l[i]; n++; }
      if (n < minBars) continue;
      add(cls, 'H', h, t1, D.close_t, D.t);
      add(cls, 'L', l, t1, D.close_t, D.t);
    }
  }
  return out;
}

export function signals(data, levels, cfg = {}) {
  const c = cfgOf(cfg);
  const { bars: m5, atr: a5 } = data.tf.M5;
  const { bars: m15, atr: a15 } = data.tf.M15;
  const raw = [];
  const ses = t => { const h = new Date(t).getUTCHours(); return h < 7 ? 'as' : h < 12 ? 'lo' : h < 17 ? 'ny' : 'pm'; };
  const emit = (Lv, sch, k, dir, entry, slRaw) => {
    if (!c.schemes.includes(sch)) return;
    const t = m5[k].close_t;
    if (new Date(t).getUTCHours() >= c.noEntryFromH) return;
    const j = L.lastClosed(m15, t);
    const minR = c.minRisk * (j >= 0 ? a15[j] : 0);
    const risk = Math.max(dir * (entry - slRaw), minR);
    if (!(risk > 0)) return;
    const sl = entry - dir * risk;
    raw.push({ t, dir, sl, tp: entry + dir * c.rr * risk, maxMin: c.maxMin, entry_ref: entry, prio: PRIO[Lv.cls],
      tags: { sch, sc: sch + '_' + Lv.cls, ss: sch + '_' + ses(t) } });
  };
  for (const Lv of levels) {
    const P = Lv.price, s = Lv.side, o = -s;           // o: chiều vượt qua cản
    const beyond = x => o * (x - P);
    const w = c.zb ? (Lv.hi - Lv.lo) / 2 : 0;         // zb: bật theo VÙNG (mép gần = P − o·w, mép xa = P + o·w)
    let k = L.lastClosed(m5, Lv.known_t) + 1;
    if (k < 1) k = 1;
    let armed = false, bounceDone = false, breakDone = false, sweepDone = false;
    for (; k < m5.length && m5[k].close_t <= Lv.expire_t; k++) {
      const b = m5[k], atr = a5[k - 1];
      if (!(atr > 0)) continue;
      const ext = o > 0 ? b.h : b.l, pen = beyond(ext), cb = beyond(b.c);
      if (!armed) { if (pen < -w) armed = true; continue; }
      if (pen < -w) continue;                          // chưa chạm (mép gần)
      // (1) bật ở lần chạm đầu. Đường: xuyên < swX·ATR5 và đóng quay lại phía đúng; dừng sau râu + bBuf·ATR5.
      //     Vùng (zb): đóng quay ra ngoài mép gần; dừng sau max(râu, mép xa) + bBuf·ATR5.
      if (!bounceDone) {
        bounceDone = true;
        if (c.zb) { if (cb < -w) emit(Lv, 'bounce', k, s, b.c, P + o * (Math.max(pen, w) + c.bBuf * atr)); }
        else if (pen < c.swX * atr && cb < 0) emit(Lv, 'bounce', k, s, b.c, ext + o * c.bBuf * atr);
      }
      // (2) phá vỡ tiếp diễn: nến M5 đầu tiên đóng vượt ≥ brThr·ATR5
      if (!breakDone && cb >= c.brThr * atr) {
        breakDone = true;
        emit(Lv, 'break', k, o, b.c, P - o * c.brBuf * atr);
      }
      // (3) quét rồi quay lại: lần đầu xuyên ≥ swX·ATR5, rồi một nến M5 đóng quay lại phía đúng trong swN nến (tính cả nến quét)
      if (!sweepDone && pen >= c.swX * atr) {
        sweepDone = true;
        let extr = ext;
        for (let q = k; q < Math.min(m5.length, k + c.swN) && m5[q].close_t <= Lv.expire_t; q++) {
          const bq = m5[q], eq = o > 0 ? bq.h : bq.l;
          if (beyond(eq) > beyond(extr)) extr = eq;
          if (beyond(bq.c) < 0) { emit(Lv, 'sweep', q, s, bq.c, extr + o * c.swBuf * atr); break; }
        }
      }
      if (bounceDone && breakDone && sweepDone) break;
    }
  }
  // Bỏ lệnh trùng (cùng lúc, cùng chiều, cùng nhóm) do hai cản trùng giá — giữ cản ưu tiên PW > PD > AS > LO.
  raw.sort((a, b) => a.t - b.t || a.prio - b.prio);
  const seen = new Set(), sigs = [];
  for (const x of raw) { const key = x.t + ':' + x.dir + ':' + x.tags.sch; if (seen.has(key)) continue; seen.add(key); delete x.prio; sigs.push(x); }
  return sigs;
}
