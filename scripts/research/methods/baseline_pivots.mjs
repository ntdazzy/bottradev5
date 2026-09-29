// Mốc so sánh: cản kiểu mã hiện tại — vùng râu mọi đỉnh/đáy M15/H1/H4 (thân→râu), sống 5 ngày; lệnh: chạm vùng lần đầu,
// nến M5 đóng rút râu quay lại (đóng ngoài vùng về phía cản) thì vào; dừng sau mép xa + 0,3 ATR M5; chốt 1,5R.
import * as L from '../lib.mjs';
export function levels(data, cfg = {}) {
  const out = [];
  for (const [name, N] of [['M15', 3], ['H1', 3], ['H4', 2]]) {
    const { bars, atr } = data.tf[name];
    for (const p of L.pivots(bars, N)) {
      const b = bars[p.i];
      const lo = p.high ? Math.max(b.o, b.c) : b.l, hi = p.high ? b.h : Math.min(b.o, b.c);
      out.push({ id: name + p.i + (p.high ? 'h' : 'l'), side: p.high ? -1 : 1, lo, hi, known_t: p.known_t,
        expire_t: p.known_t + 5 * 86400000, atr_src: atr[p.i], tags: { tf: name } });
    }
  }
  return out;
}
export function signals(data, levels, cfg = {}) {
  const { bars: m5, atr: a5 } = data.tf.M5;
  const sigs = [];
  for (const Lv of levels) {
    let k = L.lastClosed(m5, Lv.known_t) + 1, armed = false;
    for (; k < m5.length && m5[k].t < Lv.expire_t; k++) {
      const b = m5[k], near = Lv.side > 0 ? Lv.hi : Lv.lo, far = Lv.side > 0 ? Lv.lo : Lv.hi;
      if (!armed) { if ((Lv.side > 0 && b.l > near) || (Lv.side < 0 && b.h < near)) armed = true; continue; }
      const touched = Lv.side > 0 ? b.l <= near : b.h >= near;
      if (!touched) continue;
      const brokeBody = Lv.side > 0 ? b.c < far : b.c > far;
      if (brokeBody) break;
      const rejected = Lv.side > 0 ? b.c > near : b.c < near;
      if (rejected) {
        const ext = Lv.side > 0 ? Math.min(b.l, far) : Math.max(b.h, far);
        const sl = ext - Lv.side * 0.3 * a5[k];
        const entry = b.c;
        const r = Math.abs(entry - sl);
        sigs.push({ t: b.close_t, dir: Lv.side, sl, tp: entry + Lv.side * 1.5 * r, maxMin: 480, entry_ref: entry, tags: Lv.tags });
      }
      break; // chỉ lần chạm đầu
    }
  }
  return sigs;
}
