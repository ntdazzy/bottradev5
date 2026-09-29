// BẢN SỬA (kiểm toán) của rare_snr_strict.mjs: chỉ đổi phần lệnh chờ quét dừng lỗ cùng nến (xem FIX trong signals).
// rare_snr_strict — "Rare" SnR làm CHẶT theo docs/research/01-rare-snr.md (mục 2.5–2.8, 7, 8).
//
// Cản (mỗi khung H1/H4, tùy chọn D1), chỉ từ NẾN ĐỘNG LỰC: thân >= X*ATR14 (ATR của nến trước) và thân >= 60% biên độ.
//  - Gap SnR (R4–R7): 2 nến cùng màu liền nhau, ít nhất 1 nến động lực. Mức = C(c1). Gap giảm -> kháng cự, biên ngoài UL=H(c2);
//    gap tăng -> hỗ trợ, biên ngoài LL=L(c2).
//  - Classic A/V (R2, R3): 2 nến ngược màu, ít nhất 1 nến động lực. Mức = C(c1). A -> kháng cự, UL = max(H c1,c2);
//    V -> hỗ trợ, LL = min(L c1,c2) (đề xuất h).
//  - Phá (R12): thân nến CÙNG KHUNG đóng qua mức. Nếu nến phá là nến động lực đi đúng chiều phá -> LẬT (SBR/RBS, R13), mức mới
//    FRESH ở phía bên kia, biên ngoài = chính đường mức (tr.4: "chưa đóng qua mức đã phá thì còn"). Nến thường đóng qua -> mức chết.
//  - FRESH (R15): chỉ lần chạm đầu sau khi tạo/lật (cần giá ở hẳn phía đúng trước, như probe). Bộ đo chạy maxTouches=1.
//  - Hết hạn: lúc bị phá/lật trên khung của nó, hoặc sau lifeDays (mặc định 20 ngày).
// Câu chuyện (storyline, đề xuất k): chiều của lần LẬT gần nhất (nến động lực đóng qua một cản) trên H4 (hoặc D1); chỉ vào lệnh cùng chiều.
// Lệnh (mỗi cản tối đa 1 lệnh, ở lần chạm đầu):
//  (a) entry='rej': nến M5 chứa lần chạm đầu đóng lại về phía giao dịch so với mức -> vào ở giá mở M1 kế tiếp.
//  (b) entry='lim': lệnh chờ giấy tại đường mức; lib.simulate không khớp giá giới hạn được, nên vào ở giá mở M1 ngay sau nến M1 chạm.
//      Nếu chính nến M1 chạm đã quét qua dừng lỗ thì lệnh thật đã thua trong phút đó: không mô phỏng được -> đếm riêng (stderr).
//  SL = bên kia biên ngoài (UL/LL, hoặc râu nến M5 từ chối nếu sâu hơn) + 0,1*ATR khung cản; khoảng dừng tối thiểu 1*ATR M5.
//  TP: '2R' hoặc 'opp' = mức của cản FRESH đối diện gần nhất (đã biết lúc vào); gần hơn 1R thì bỏ lệnh; không có thì 2R (nhãn tp=2R_fb).
//
// KẾ HOẠCH ĐÃ ĐỊNH TRƯỚC KHI CHẠY (tối đa 8 cấu hình, đều maxTouches=1):
//  C1 X=1.0 rej 2R story=H4 | C2 X=1.5 rej 2R story=H4
//  -> chọn X* = cấu hình có (diff - ci95) nhóm tat_ca lớn hơn; bằng nhau thì diff lớn hơn; vẫn bằng thì X=1.5.
//  Trên X*: C3 lim 2R H4 | C4 rej opp H4 | C5 lim opp H4 | C6 rej 2R D1 | C7 lim 2R D1 | C8 rej 2R story=none (đối chứng, không được chọn).
//  Đóng băng: trong các cấu hình dùng X* (trừ C8) có >= 100 lệnh, lấy cấu hình có meanR - random.meanR lớn nhất;
//  không có cấu hình nào đủ 100 lệnh thì lấy cấu hình gốc của X* (C1 hoặc C2).
import * as L from '../lib.mjs';

const MIN = L.MIN, DAY = 86400000;
const cache = new Map();

function build(data, cfg) {
  const X = cfg.X ?? 1.0, life = (cfg.lifeDays ?? 20) * DAY;
  const key = JSON.stringify([X, life, cfg.tfs]);
  if (cache.has(key)) return cache.get(key);
  const m = data.m;
  const engine = (name) => {
    const { bars, atr } = data.tf[name];
    const mom = new Int8Array(bars.length); // +1 / -1 nến động lực tăng / giảm, 0 không
    for (let k = 1; k < bars.length; k++) {
      const b = bars[k], body = Math.abs(b.c - b.o), rg = b.h - b.l;
      if (body > 0 && body >= X * atr[k - 1] && body >= 0.6 * rg) mom[k] = b.c > b.o ? 1 : -1;
    }
    const recs = [], flips = [];
    let live = [];
    const add = (o) => { const r = { id: `${name}_${recs.length}`, tf: name, dead_t: null, ...o }; recs.push(r); live.push(r); };
    for (let k = 1; k < bars.length; k++) {
      const b = bars[k];
      // 1) cản đã có: hết hạn / bị thân nến đóng qua (phá hoặc lật)
      const keep = [];
      for (const r of live) {
        if (r.known_t + life <= b.t) continue;
        const broke = r.side > 0 ? b.c < r.lvl : b.c > r.lvl;
        if (!broke) { keep.push(r); continue; }
        r.dead_t = b.close_t;
        if (mom[k] === -r.side) {
          flips.push({ t: b.close_t, dir: mom[k] });
          const nr = { side: -r.side, lvl: r.lvl, outer: r.lvl, known_t: b.close_t, atr_src: atr[k], type: 'flip', origin: r.type };
          recs.push({ id: `${name}_${recs.length}`, tf: name, dead_t: null, ...nr });
          keep.push(recs[recs.length - 1]);
        }
      }
      live = keep;
      // 2) mẫu mới từ cặp (k-1, k)
      const c1 = bars[k - 1], c2 = b;
      const d1 = Math.sign(c1.c - c1.o), d2 = Math.sign(c2.c - c2.o);
      if (!d1 || !d2 || !(mom[k - 1] || mom[k])) continue;
      const lvl = c1.c;
      let side, outer, type;
      if (d1 === d2) { type = 'gap'; if (d1 < 0) { side = -1; outer = Math.max(c2.h, lvl); } else { side = 1; outer = Math.min(c2.l, lvl); } }
      else { type = 'classic'; if (d1 > 0) { side = -1; outer = Math.max(c1.h, c2.h, lvl); } else { side = 1; outer = Math.min(c1.l, c2.l, lvl); } }
      if (side > 0 ? !(c2.c > lvl) : !(c2.c < lvl)) continue; // giá lúc biết cản phải ở đúng phía
      add({ side, lvl, outer, known_t: c2.close_t, atr_src: atr[k], type });
    }
    return { recs, flips };
  };
  const tfs = cfg.tfs ?? ['H1', 'H4'];
  const eng = {};
  for (const n of new Set([...tfs, 'H4', 'D1'])) eng[n] = engine(n);
  // câu chuyện: chiều lần lật gần nhất đã biết tại t
  const story = (tf, t) => {
    const f = eng[tf].flips;
    let lo = 0, hi = f.length - 1, ans = -1;
    while (lo <= hi) { const mid = (lo + hi) >> 1; if (f[mid].t <= t) { ans = mid; lo = mid + 1; } else hi = mid - 1; }
    return ans < 0 ? 0 : f[ans].dir;
  };
  const out = [];
  for (const n of tfs) for (const r of eng[n].recs) {
    r.expire_t = Math.min(r.dead_t ?? Infinity, r.known_t + life);
    // lần chạm đầu (FRESH): cần 1 nến M1 nằm hẳn phía đúng rồi mới tính chạm đường mức
    let i = L.idxAt(m, r.known_t);
    const iEnd = Math.min(m.n, L.idxAt(m, r.expire_t));
    let armed = false; r.touch_i = null; r.touch_t = Infinity;
    for (; i < iEnd; i++) {
      if (!armed) { if (r.side > 0 ? m.l[i] > r.lvl : m.h[i] < r.lvl) armed = true; continue; }
      if (r.side > 0 ? m.l[i] <= r.lvl : m.h[i] >= r.lvl) { r.touch_i = i; r.touch_t = m.t[i] + MIN; break; }
    }
    r.lo = r.side > 0 ? r.outer : r.lvl;
    r.hi = r.side > 0 ? r.lvl : r.outer;
    const s = story('H4', r.known_t);
    r.tags = { tf: n, type: r.type, story_h4: s === 0 ? 'chua_co' : (s === r.side ? 'cung' : 'nguoc') };
    out.push(r);
  }
  const res = { out, story };
  cache.set(key, res);
  return res;
}

export function levels(data, cfg = {}) {
  return build(data, cfg).out;
}

export function signals(data, levels, cfg = {}) {
  const { story } = build(data, cfg);
  const m = data.m, { bars: m5, atr: a5 } = data.tf.M5;
  const entry = cfg.entry ?? 'rej', tpMode = cfg.tp ?? '2R', storyTF = cfg.story ?? 'H4';
  const life = (cfg.lifeDays ?? 20) * DAY;
  const cnt = { cham: 0, khong_tu_choi: 0, sl_cung_nen: 0, nguoc_story: 0, opp_gan: 0, trung: 0, lenh: 0 };
  const sigs = [], seen = new Set();
  const order = levels.slice().sort((a, b) => (a.touch_t - b.touch_t) || (a.tf === 'H4' ? -1 : 1));
  for (const r of order) {
    if (r.touch_i == null) continue;
    cnt.cham++;
    const i = r.touch_i, dir = r.side;
    let t, ref, ext;
    if (entry === 'rej') {
      const k = L.lastClosed(m5, m.t[i]) + 1;
      const b = m5[k];
      if (!b || !(b.t <= m.t[i] && m.t[i] < b.close_t)) continue;
      if (!(dir > 0 ? b.c > r.lvl : b.c < r.lvl)) { cnt.khong_tu_choi++; continue; }
      t = b.close_t; ref = b.c; ext = dir > 0 ? Math.min(r.outer, b.l) : Math.max(r.outer, b.h);
    } else {
      t = m.t[i] + MIN; ref = m.c[i]; ext = r.outer;
    }
    if (r.dead_t != null && r.dead_t < t) continue;
    const k5 = L.lastClosed(m5, entry === 'rej' ? t : m.t[i]);
    const atr5 = k5 >= 0 ? a5[k5] : 0;
    if (!(atr5 > 0)) continue;
    const anchor = entry === 'rej' ? ref : r.lvl;
    let sl = ext - dir * 0.1 * r.atr_src;
    if (dir * (anchor - sl) < atr5) sl = anchor - dir * atr5;
    // FIX (kiểm toán): lệnh chờ tại đường mức đã khớp trong nến chạm; nếu chính nến đó quét qua dừng lỗ thì lệnh thật THUA.
    // Bản gốc bỏ các lệnh này (lọc bỏ lệnh thua). Ở đây giữ lại: vào ở giá mở nến chạm (t = m.t[i]) để simulate tính dừng lỗ ngay nến đó.
    let swept = false;
    if (entry === 'lim' && (dir > 0 ? m.l[i] <= sl : m.h[i] + L.COST.spread >= sl)) { cnt.sl_cung_nen++; swept = true; t = m.t[i]; ref = r.lvl; }
    if (storyTF !== 'none' && story(storyTF, t) !== dir) { cnt.nguoc_story++; continue; }
    const risk = dir * (ref - sl);
    if (!(risk > 0)) continue;
    let tp = ref + dir * 2 * risk, tpsrc = '2R';
    if (tpMode === 'opp') {
      let best = null;
      for (const o of levels) {
        if (o.side !== -dir || o.known_t > t || o.touch_t <= t || (o.dead_t != null && o.dead_t <= t) || o.known_t + life <= t) continue;
        const d = dir * (o.lvl - ref);
        if (d > 0 && (best == null || d < best)) best = d;
      }
      if (best != null) { if (best < risk) { cnt.opp_gan++; continue; } tp = ref + dir * best; tpsrc = 'opp'; }
      else tpsrc = '2R_fb';
    }
    const key = t + ':' + dir;
    if (seen.has(key)) { cnt.trung++; continue; }
    seen.add(key);
    cnt.lenh++;
    sigs.push({ t, dir, sl, tp, maxMin: 720, entry_ref: ref, tags: { tf: r.tf, type: r.type, tp: tpsrc, ...(swept ? { quet_sl: 'co' } : {}) } });
  }
  console.error('rare_snr_strict dem:', JSON.stringify(cnt));
  return sigs;
}
