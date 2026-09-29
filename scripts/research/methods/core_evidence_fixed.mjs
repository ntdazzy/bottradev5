// core_evidence_fixed — bản SỬA của kiểm toán viên (auditor) cho core_evidence.mjs (bản gốc giữ nguyên).
// LỖI SỬA: đối chứng giả không công bằng — expire_t của cản thật do chính tương tác giá với cản đó quyết định (E hết hạn ở nến M15 đầu
//   tiên đóng trong vùng, R bị thay khi giá đi xa 1 bậc / đóng qua), cản giả dùng chung expire_t nên lần chạm của cản thật bị cắt khác hẳn
//   cản giả (C2: E thật 66,7% vs giả 12,6%). SỬA (định trước khi chạy): levels() giữ nguyên các lần KÍCH HOẠT của bản gốc, nhưng mỗi cản
//   sống cố định maxAgeDays (5 ngày) từ known_t, không phụ thuộc giá sau đó; probe tự xác định bị phá. Bỏ lần kích hoạt nếu cùng danh tính
//   (R: mức X + phía; E: cụm + phía) còn sống. signals() KHÔNG đổi: chạy đúng luật lệnh cũ trên các cản động của bản gốc (tính lại bên
//   trong), nên kết quả lệnh phải trùng hệt bản gốc cùng cấu hình.
//
// HỌ R (số tròn, Osler 2003): bội số $100 / $50 / $10 (mỗi mức gắn bậc lớn nhất nó thuộc). Tại mỗi lần đóng nến M15, với từng bậc chỉ giữ
//   1 mức gần nhất PHÍA DƯỚI giá (hỗ trợ) và 1 mức gần nhất PHÍA TRÊN (kháng cự). Vùng = X ± gK*ATR(M5) (ATR M5 lúc kích hoạt).
// HỌ E (đỉnh/đáy đã được tôn trọng): đầu râu pivot M15(N=3)/H1(N=3)/H4(N=2), chỉ dùng từ known_t. Pivot mới gộp vào cụm đang sống nếu
//   bề rộng cụm (cao nhất − thấp nhất các đầu râu) ≤ W = k*ATR(M15) lúc gộp; pivot trùng giá + trùng thời gian ở khung khác = cùng một
//   đỉnh/đáy (không đếm 2 lần). Vùng = [thấp nhất, cao nhất] ± padK*ATR(M15).
//   Điểm(t) = Σ_đỉnh/đáy 0,5^(tuổi/T½) − 2·Σ_lần thân M15 đóng xuyên qua 0,5^(tuổi/T½).
//   Cụm chết khi bị thân M15 đóng xuyên 2 lần hoặc đỉnh/đáy mới nhất quá maxAgeDays.
//   Chọn tại mỗi lần đóng M15: cụm có ≥ 2 đỉnh/đáy, giá đóng nằm ngoài vùng, điểm ≥ minScore → NMS (mạnh nhất trước, bỏ vùng chồng)
//   → giữ tối đa 2 vùng trên + 2 vùng dưới giá (theo điểm). Mỗi đợt được chọn liên tục = 1 cản (known_t = lúc chọn, expire_t = lúc bị bỏ
//   chọn / đổi phía / đổi biên). Mọi quyết định chỉ dùng nến đã đóng ≤ thời điểm quyết định.
// LỆNH (trên M5, nhóm nhãn riêng grp = <họ>_<kiểu>):
//   bounce: sau khi giá ở hẳn phía đúng, lần chạm đầu; trong rejBars nến M5 (kể cả nến chạm) có nến đóng lại ra ngoài mép gần, đóng ở nửa
//     thuận của nến, chưa đóng qua mép xa → vào theo chiều cản. SL = đáy/đỉnh xa nhất kể từ lúc chạm (hoặc mép xa nếu xa hơn) + slBuf*ATR5
//     (không đặt sát sau số tròn/đỉnh đáy). TP = tpR*R.
//   break: nến M5 đầu tiên đóng qua mép xa quá 0,1*ATR5 (giống định nghĩa "bị phá" của probe), thân ≥ bodyK*ATR5 cùng chiều phá, đóng ở
//     1/3 ngoài cùng → vào theo chiều phá. SL = lại vào trong vùng: mép gần (phía giá đến) + slBuf*ATR5. TP = tpR*R.
//   Khoảng dừng tối thiểu = 4*(spread + 2 chặng trượt) = 3,04 USD (nới SL ra nếu hẹp hơn); bỏ lệnh nếu khoảng dừng > maxRiskA5*ATR5.
//   Trùng (cùng nến, cùng chiều) → giữ lệnh đầu.
//
// KẾ HOẠCH ĐÃ ĐỊNH TRƯỚC KHI CHẠY (8 cấu hình, đều trên discovery; nhóm chính khai báo trước = tat_ca). Đã kiểm cơ chế (không nhìn
// trước, số cản) chỉ trên dữ liệu nền 01–02/2025 bằng core_evidence_check.mjs, chưa xem kết quả bật/lệnh nào.
//  C1 gốc: k=0.5 hl=2 minScore=1 steps=[100,50,10] gK=0.1 gapK=0.5 padK=0.1 slBuf=0.5 tpR=1.5
//  C2 steps=[100,50] (bỏ $10) | C3 k=1 | C4 hl=1 | C5 hl=5 | C6 minScore=2 | C7 tpR=2 | C8 slBuf=1.0 + gK=0.2
//  LUẬT ĐÓNG BĂNG (định trước khi xem kết quả): chỉ xét cấu hình có levels_per_day < 23,1 (mốc) và overlap.p50 ≤ 1; lấy cấu hình có
//  cận dưới (diff − ci95) nhóm tat_ca lớn nhất; các cấu hình cách nhau ≤ 1,0 điểm cận dưới thì lấy cấu hình có (meanR − random.meanR)
//  lớn nhất; vẫn bằng thì ít cản/ngày hơn. Không cấu hình nào đủ điều kiện → lấy cấu hình ít cản/ngày nhất.
//
// LỖI THIẾT KẾ ĐÃ BIẾT (phát hiện SAU khi chạy 8 cấu hình, giữ nguyên mã để kết quả tái lập được; xem core_evidence_diag.mjs):
//  expire_t của cản phụ thuộc chính tương tác giá với cản đó (E: hết hạn ngay khi nến M15 đóng TRONG vùng; R: hết hạn khi M15 đóng qua
//  hoặc giá đi xa 1 bậc). Cản giả dùng chung expire_t nên bị cắt ở lúc không liên quan. Đo C1: lần chạm bị cắt trước khi kịp bật/phá
//  E thật 66,7% vs E giả 12,4%; R thật 15,1% vs R giả 28,2% → diff họ E bị kéo xuống, diff họ R bị đẩy lên. Số "bật" của 8 cấu hình
//  KHÔNG đáng tin. Lệnh không bị cắt (chạy tới SL/TP/hết giờ) nên so với ngẫu nhiên vẫn đúng cách đo. Sửa cho vòng sau: đời cản cố định
//  từ lúc kích hoạt (chỉ chọn "2 trên + 2 dưới"/"gần nhất" tại lúc kích hoạt), để probe tự xác định bị phá.
import * as L from '../lib.mjs';

const DAY = 86400000;
const TFR = { M15: 1, H1: 2, H4: 3 };

function P(cfg) {
  return {
    k: cfg.k ?? 0.5, hl: (cfg.hl ?? 2) * DAY, minScore: cfg.minScore ?? 1.0, maxAge: (cfg.maxAgeDays ?? 5) * DAY,
    padK: cfg.padK ?? 0.1, perSide: cfg.perSide ?? 2,
    steps: cfg.steps ?? [100, 50, 10], gK: cfg.gK ?? 0.1, gapK: cfg.gapK ?? 0.5,
    slBuf: cfg.slBuf ?? 0.5, tpR: cfg.tpR ?? 1.5, bodyK: cfg.bodyK ?? 0.6, rejBars: cfg.rejBars ?? 3,
    maxMin: cfg.maxMin ?? 240, minRisk: cfg.minRisk ?? 4 * (L.COST.spread + 2 * L.COST.slip), maxRiskA5: cfg.maxRiskA5 ?? 5,
  };
}

const rcls = X => (X % 100 === 0 ? 100 : X % 50 === 0 ? 50 : 10);

// ---------------------------------------------------------------- họ R
function levelsR(data, p) {
  const { bars: m15, atr: a15 } = data.tf.M15;
  const { bars: m5, atr: a5 } = data.tf.M5;
  // Một cản cho mỗi (bậc, phía). Kích hoạt mức gần nhất cách giá đóng ≥ g + gapK*ATR15 (trễ để giá chạy quanh số tròn không đẻ cản
  // liên tục). Cản đang sống kết thúc khi: M15 đóng qua mép xa (đổi phía), có mức cùng bậc gần giá hơn đủ điều kiện kích hoạt, hoặc quá tuổi.
  const out = [], active = new Map();
  let lastT = 0;
  for (let k = 0; k < m15.length; k++) {
    const b = m15[k], T = b.close_t, c = b.c;
    const i5 = L.lastClosed(m5, T);
    if (i5 < 20 || k < 20) continue;
    lastT = T;
    const g = p.gK * a5[i5], d = g + p.gapK * a15[k];
    for (const step of p.steps) for (const side of [1, -1]) {
      const key = `${step}|${side}`;
      let X;
      if (side > 0) { X = Math.floor((c - d) / 10) * 10; if (X > c - d) X -= 10; while (rcls(X) !== step) X -= 10; }
      else { X = Math.ceil((c + d) / 10) * 10; if (X < c + d) X += 10; while (rcls(X) !== step) X += 10; }
      const cur = active.get(key);
      if (cur) {
        const broken = side > 0 ? c < cur.lo : c > cur.hi;
        const closer = Math.abs(c - X) < Math.abs(c - cur.X);
        if (!broken && !closer && T - cur.known_t < p.maxAge) continue;
        cur.expire_t = T; out.push(cur); active.delete(key);
      }
      active.set(key, { id: `R${X}_${side}_${T}`, X, side, lo: X - g, hi: X + g, known_t: T, expire_t: 0, atr_src: a15[k],
        tags: { fam: 'R', step: String(step) } });
    }
  }
  for (const inst of active.values()) { inst.expire_t = lastT; out.push(inst); }
  return out;
}

// ---------------------------------------------------------------- họ E
function levelsE(data, p) {
  const { bars: m15, atr: a15 } = data.tf.M15;
  const piv = [];
  for (const [name, N] of [['M15', 3], ['H1', 3], ['H4', 2]]) {
    const bars = data.tf[name].bars;
    for (const q of L.pivots(bars, N)) {
      const pb = bars[q.i];
      piv.push({ tf: name, price: q.price, t0: pb.t, t1: pb.close_t, known_t: q.known_t });
    }
  }
  piv.sort((a, b) => a.known_t - b.known_t);
  let zones = [], zid = 0, pp = 0;
  const out = [], active = new Map();
  const score = (z, T) => {
    let s = 0;
    for (const w of z.sw) s += Math.pow(0.5, (T - w.t1) / p.hl);
    for (const x of z.cr) s -= 2 * Math.pow(0.5, (T - x) / p.hl);
    return s;
  };
  const posOf = (z, c) => (c > z.hi + z.pad ? 1 : c < z.lo - z.pad ? -1 : 0);
  let lastT = 0;
  for (let k = 0; k < m15.length; k++) {
    const b = m15[k], T = b.close_t, A = a15[k];
    lastT = T;
    // 1) thân M15 đóng xuyên qua vùng (chỉ với cụm đã có trước khi nến này mở)
    for (const z of zones) {
      if (z.created_t > b.t) continue;
      const pos = posOf(z, b.c);
      if (pos !== 0) { if (z.pos !== 0 && pos !== z.pos) z.cr.push(T); z.pos = pos; }
    }
    // 2) thêm pivot đã được xác nhận (known_t ≤ T)
    while (pp < piv.length && piv[pp].known_t <= T) {
      const q = piv[pp++];
      if (k < 20) continue;
      let dup = null;
      for (const z of zones) for (const w of z.sw)
        if (Math.abs(w.price - q.price) < 1e-6 && w.t0 < q.t1 && q.t0 < w.t1) dup = w;
      if (dup) { if (TFR[q.tf] > TFR[dup.tf]) dup.tf = q.tf; continue; }
      const W = p.k * A;
      let best = null, bd = Infinity;
      for (const z of zones) {
        if (Math.max(z.hi, q.price) - Math.min(z.lo, q.price) > W) continue;
        const d = Math.abs((z.lo + z.hi) / 2 - q.price);
        if (d < bd) { bd = d; best = z; }
      }
      if (best) {
        best.sw.push(q); best.lo = Math.min(best.lo, q.price); best.hi = Math.max(best.hi, q.price);
        best.pad = p.padK * A; best.ver++; best.last = Math.max(best.last, q.t1);
      } else {
        const z = { id: zid++, lo: q.price, hi: q.price, pad: p.padK * A, sw: [q], cr: [], pos: 0, created_t: T, ver: 0, last: q.t1 };
        z.pos = posOf(z, b.c);
        zones.push(z);
      }
    }
    // 3) cụm chết
    zones = zones.filter(z => z.cr.length < 2 && T - z.last <= p.maxAge);
    // 4) chọn: đủ ≥2 đỉnh/đáy, giá ngoài vùng, điểm ≥ ngưỡng → NMS → 2 trên + 2 dưới
    const cands = [];
    for (const z of zones) {
      if (z.sw.length < 2) continue;
      const pos = posOf(z, b.c);
      if (pos === 0) continue;
      const s = score(z, T);
      if (s >= p.minScore) cands.push({ z, s, pos });
    }
    cands.sort((a, b2) => b2.s - a.s);
    const kept = [];
    for (const c of cands) {
      const lo = c.z.lo - c.z.pad, hi = c.z.hi + c.z.pad;
      if (kept.some(o => o.z.lo - o.z.pad <= hi && o.z.hi + o.z.pad >= lo)) continue;
      kept.push(c);
    }
    const sel = new Map();
    for (const pos of [1, -1]) for (const c of kept.filter(x => x.pos === pos).slice(0, p.perSide)) sel.set(c.z.id, c);
    for (const [id, inst] of active) {
      const c = sel.get(id);
      if (!c || inst.side !== c.pos || inst.ver !== c.z.ver) { inst.expire_t = T; out.push(inst); active.delete(id); }
    }
    for (const [id, c] of sel) {
      if (active.has(id)) continue;
      const z = c.z;
      const tf = z.sw.reduce((m, w) => (TFR[w.tf] > TFR[m] ? w.tf : m), 'M15');
      active.set(id, { id: `E${id}_${z.ver}_${T}`, side: c.pos, lo: z.lo - z.pad, hi: z.hi + z.pad, known_t: T, expire_t: 0,
        atr_src: A, ver: z.ver, zid: id, tags: { fam: 'E', tf, nsw: z.sw.length >= 3 ? '3+' : '2' } });
    }
  }
  for (const inst of active.values()) { inst.expire_t = lastT; out.push(inst); }
  return out;
}

function dynLevels(data, p) {
  return levelsR(data, p).concat(levelsE(data, p));
}

// Cản cho probe: cùng lần kích hoạt, đời cố định p.maxAge từ known_t (không phụ thuộc giá sau kích hoạt).
export function levels(data, cfg = {}) {
  const p = P(cfg);
  const dyn = dynLevels(data, p).slice().sort((a, b) => a.known_t - b.known_t);
  const until = new Map(), out = [];
  for (const x of dyn) {
    const key = (x.tags.fam === 'R' ? 'R' + x.X : 'E' + x.zid) + '|' + x.side;
    if ((until.get(key) ?? -Infinity) > x.known_t) continue;
    const e = x.known_t + p.maxAge;
    until.set(key, e);
    out.push({ ...x, expire_t: e });
  }
  return out;
}

// ---------------------------------------------------------------- lệnh
export function signals(data, levels, cfg = {}) {
  const p = P(cfg);
  const { bars: m5, atr: a5 } = data.tf.M5;
  const sigs = [];
  const mk = (b, dir, sl, a, Lv, kind) => {
    const entry = b.c;
    let risk = Math.abs(entry - sl);
    if (risk > p.maxRiskA5 * a) return;
    if (risk < p.minRisk) { risk = p.minRisk; sl = entry - dir * risk; }
    sigs.push({ t: b.close_t, dir, sl, tp: entry + dir * p.tpR * risk, maxMin: p.maxMin, entry_ref: entry,
      tags: { ...Lv.tags, sig: kind, grp: `${Lv.tags.fam}_${kind}` } });
  };
  // Lệnh chạy trên cản động của bản gốc (lọc y như runner) — luật lệnh không đổi.
  const dyn = dynLevels(data, p).filter(x => x.expire_t > data.from_t && x.known_t < data.to_t);
  for (const Lv of dyn) {
    const s = Lv.side, near = s > 0 ? Lv.hi : Lv.lo, far = s > 0 ? Lv.lo : Lv.hi;
    let k = L.lastClosed(m5, Lv.known_t) + 1, armed = false, touchK = -1, ext = 0, bounceDone = false;
    for (; k < m5.length && m5[k].close_t <= Lv.expire_t; k++) {
      const b = m5[k], a = a5[k];
      if (!armed) { if ((s > 0 && b.l > near) || (s < 0 && b.h < near)) armed = true; continue; }
      const touched = s > 0 ? b.l <= near : b.h >= near;
      if (touchK < 0 && touched) { touchK = k; ext = s > 0 ? b.l : b.h; }
      if (touchK >= 0) ext = s > 0 ? Math.min(ext, b.l) : Math.max(ext, b.h);
      const broke = s > 0 ? b.c < far - 0.1 * a : b.c > far + 0.1 * a;
      if (broke) {
        const dir = -s, body = (b.c - b.o) * dir, rg = b.h - b.l;
        const tail = dir > 0 ? b.h - b.c : b.c - b.l;
        if (body >= p.bodyK * a && tail <= rg / 3) mk(b, dir, near - dir * p.slBuf * a, a, Lv, 'break');
        break;
      }
      if (bounceDone || touchK < 0) continue;
      if (k - touchK >= p.rejBars) { bounceDone = true; continue; }
      const rej = s > 0 ? b.c > near && b.c >= b.l + 0.5 * (b.h - b.l) : b.c < near && b.c <= b.h - 0.5 * (b.h - b.l);
      if (rej) {
        const x = s > 0 ? Math.min(ext, far) : Math.max(ext, far);
        mk(b, s, x - s * p.slBuf * a, a, Lv, 'bounce');
        bounceDone = true;
      }
    }
  }
  sigs.sort((x, y) => x.t - y.t || x.dir - y.dir);
  const seen = new Set();
  return sigs.filter(x => { const key = x.t + '|' + x.dir; if (seen.has(key)) return false; seen.add(key); return true; });
}
