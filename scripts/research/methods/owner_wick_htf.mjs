// owner_wick_htf — cản RÂU của đỉnh/đáy LỚN khung H1/H4/D1 theo luật trên chart của chủ bot (SPEC 22.4, 23.2 L1, 23.3 K1, 23.4, 24.5).
//
// CẢN (mỗi khung trong cfg.tfs, pivot fractal N: H1=3, H4=2, D1=2 theo SPEC mục 13):
//  - Đỉnh/đáy fractal N nến mỗi bên (L.pivots) VÀ là cực trị của ít nhất R nến bên trái (không nến nào trong R nến trước có đỉnh >= / đáy <=).
//  - Phá cấu trúc (cfg.bos, mặc định bật): đáy fractal gần nhất TRƯỚC đỉnh (với kháng cự) — hoặc đỉnh fractal gần nhất trước đáy (với hỗ trợ) —
//    bị THÂN nến cùng khung đóng qua trong W nến sau pivot, và trước đó giá chưa vượt râu của pivot.
//  - Vùng = râu nến pivot: kháng cự [max(O,C), H], hỗ trợ [L, min(O,C)]. Đầu râu = H (hoặc L); giữa râu = (mép thân + đầu râu)/2.
//  - Biết lúc: max(nến xác nhận thứ N đóng, nến phá cấu trúc đóng). Hết hạn: nến cùng khung đóng qua đầu râu, hoặc tuổi từ nến gốc
//    H1 5 ngày, H4 21 ngày, D1 90 ngày (SPEC 24.5; cfg.life='long': 21 / 63 / 180 ngày).
//  - Cùng một đầu râu thấy ở nhiều khung: bản khung lớn thay bản khung nhỏ TỪ LÚC bản lớn được biết (bản nhỏ hết hạn lúc đó; nếu bản lớn đã có
//    trước thì bỏ bản nhỏ). Không dùng thông tin tương lai.
//
// LỆNH (K1, mỗi lần kiểm tra tối đa 1 lệnh, tối đa 3 lần kiểm tra mỗi cản):
//  - Lần kiểm tra = giá đã ở hẳn ngoài vùng (một nến M5 đã đóng nằm hoàn toàn phía đúng) rồi chạm mép gần (mép thân). Kết thúc khi lại có
//    một nến M5 nằm hẳn ngoài vùng. Nến M5 đóng qua đầu râu thêm 0,1 ATR M5 → hủy lần kiểm tra này (không vào).
//  - Mốc vào: lần kiểm tra ĐẦU (FRESH) = đầu râu; từ lần 2 = giữa râu (cfg.later='mid') hoặc đầu râu (cfg.later='tip').
//  - entry='rej': trong nến M5 chạm mốc và 2 nến sau, nến M5 đầu tiên đóng lại về phía lệnh so với mốc và có màu theo chiều lệnh
//    (bán: C<mốc và C<=O; mua đối xứng) → vào thị trường ở giá mở M1 kế tiếp.
//  - entry='m1touch' (thay cho "lệnh chờ giấy tại mốc", vì lib.simulate chỉ vào ở giá mở): nến M1 đầu tiên chạm mốc; khi nó đóng, nếu
//    nó CHƯA chạm dừng lỗ → vào thị trường ở giá mở M1 kế tiếp; nếu đã chạm dừng lỗ → bỏ (đếm riêng ra stderr).
//  - Dừng lỗ: bán = max(đầu râu, cực trị đã thấy trong lần kiểm tra) + buf·ATR M5 + spread; mua = min(...) − buf·ATR M5.
//  - Chốt lời (cfg.tp='dol'): DOL = đỉnh (mua) / đáy (bán) fractal H1/H4/D1 gần nhất phía trước, đã biết và CHƯA bị giá quét tới lúc vào;
//    nếu cách giá vào >= 1,5R → chốt ở DOL, không thì 2R. cfg.tp='2R' → luôn 2R. Hết giờ: maxMin phút (mặc định 1440, SPEC 22.3: 24 giờ).
//  - Gộp (SPEC 24.2): nhiều lệnh cùng thời điểm, cùng chiều → giữ một (khung lớn hơn, rồi lần kiểm tra sớm hơn).
//
// KẾ HOẠCH ĐÃ ĐỊNH TRƯỚC KHI CHẠY runner (8 cấu hình, đều trên discovery; mặc định: tfs=[H1,H4,D1], bos=true, W=20, life=spec,
// entry=rej, later=mid, buf=0.3, tp=dol, maxMin=1440). Sửa một lần trước lượt runner đầu tiên, sau khi chỉ đếm phễu (không xem bật/lệnh):
// R=20 + phá cấu trúc chỉ còn 130 cản, 62 cản được giá quay lại trong tuổi SPEC 24.5 → thêm biến thể tuổi dài.
//  Giai đoạn bộ cản: C1 R=20 | C2 R=50 → R* = cấu hình có (diff − ci95) nhóm tat_ca lớn hơn; chênh < 0,5 điểm thì R=50 (ít cản hơn).
//    C3 R*, life=long (H1 21 ngày, H4 63 ngày, D1 180 ngày) | C4 R*, bos=false (đối chứng bỏ lọc phá cấu trúc).
//  ĐÓNG BĂNG bước 1 — bộ cản S*: trong {bộ R* gốc, C3, C4} lấy bộ có (diff − ci95) nhóm tat_ca lớn nhất trong các bộ có n_real >= 150
//    (không bộ nào đủ thì lấy bộ có n_real lớn nhất); chênh < 0,5 điểm thì lấy bộ ít cản/ngày hơn. Bước này KHÔNG dùng kết quả lệnh.
//  Giai đoạn lệnh trên S*: C5 entry=m1touch | C6 later=tip | C7 buf=0.5 | C8 tp=2R.
//  ĐÓNG BĂNG bước 2 — trong {cấu hình gốc của S*, C5–C8} lấy cấu hình có (meanR − random.meanR) lớn nhất trong các cấu hình có >= 100 lệnh;
//    không cấu hình nào đủ 100 lệnh thì lấy cấu hình gốc của S* (luật vào mặc định của chủ bot).
import * as L from '../lib.mjs';

const DAY = 86400000, MIN = L.MIN;
const PIV_N = { H1: 3, H4: 2, D1: 2 };
const LIFE = { spec: { H1: 5 * DAY, H4: 21 * DAY, D1: 90 * DAY }, long: { H1: 21 * DAY, H4: 63 * DAY, D1: 180 * DAY } };
const RANK = { H1: 1, H4: 2, D1: 3 };

// Số nến bên trái trước khi gặp nến có đỉnh >= (đáy <=) đỉnh/đáy của nến i, tối đa cap.
function leftStrength(bars, i, high, cap = 500) {
  let k = 0;
  for (let j = i - 1; j >= 0 && k < cap; j--, k++) if (high ? bars[j].h >= bars[i].h : bars[j].l <= bars[i].l) break;
  return k;
}
const strTag = k => (k >= 200 ? '>=200' : k >= 50 ? '50-200' : '<50');

export function levels(data, cfg = {}) {
  const R = cfg.R ?? 20, W = cfg.W ?? 20, bos = cfg.bos ?? true, tfs = cfg.tfs ?? ['H1', 'H4', 'D1'];
  const all = [];
  for (const tf of tfs) {
    const { bars, atr } = data.tf[tf], N = PIV_N[tf];
    let lastHigh = null, lastLow = null;
    for (const p of L.pivots(bars, N)) {
      const opp = p.high ? lastLow : lastHigh;
      if (p.high) lastHigh = p; else lastLow = p;
      const str = leftStrength(bars, p.i, p.high);
      if (str < R) continue;
      const b = bars[p.i], tip = p.high ? b.h : b.l, body = p.high ? Math.max(b.o, b.c) : Math.min(b.o, b.c);
      let kb = p.i + N;
      if (bos) {
        if (!opp) continue;
        let k = p.i + 1, bosK = -1;
        for (; k <= Math.min(p.i + W, bars.length - 1); k++) {
          const x = bars[k];
          if (p.high ? x.h > tip : x.l < tip) break;                     // râu bị vượt trước khi phá cấu trúc
          if (p.high ? x.c < opp.price : x.c > opp.price) { bosK = k; break; }
        }
        if (bosK < 0) continue;
        kb = Math.max(kb, bosK);
      }
      if (kb >= bars.length) continue;
      const known_t = bars[kb].close_t;
      let expire_t = b.t + LIFE[cfg.life ?? 'spec'][tf];
      for (let k = kb + 1; k < bars.length && bars[k].t < expire_t; k++)
        if (p.high ? bars[k].c > tip : bars[k].c < tip) { expire_t = Math.min(expire_t, bars[k].close_t); break; }
      if (!(expire_t > known_t)) continue;
      all.push({ id: `${tf}_${p.i}${p.high ? 'h' : 'l'}`, side: p.high ? -1 : 1, lo: Math.min(body, tip), hi: Math.max(body, tip),
        known_t, expire_t, atr_src: atr[p.i], tags: { tf, str: strTag(str) },
        tf, tip, body, mid: (body + tip) / 2 });
    }
  }
  // cùng đầu râu ở nhiều khung: bản khung lớn thay bản khung nhỏ từ lúc bản lớn được biết
  const byTip = new Map();
  for (const x of all) { const k = x.side + ':' + x.tip; if (!byTip.has(k)) byTip.set(k, []); byTip.get(k).push(x); }
  const drop = new Set();
  for (const g of byTip.values()) {
    if (g.length < 2) continue;
    for (const lo of g) for (const hi of g) {
      if (RANK[hi.tf] <= RANK[lo.tf]) continue;
      if (hi.known_t <= lo.known_t) { if (lo.known_t < hi.expire_t) drop.add(lo); }
      else if (hi.known_t < lo.expire_t) lo.expire_t = hi.known_t;
    }
  }
  return all.filter(x => !drop.has(x) && x.expire_t > x.known_t);
}

// Đỉnh/đáy fractal H1/H4/D1 cho đích DOL, kèm lúc bị quét (giờ mở nến M1 đầu tiên vượt giá đó; Infinity nếu chưa).
function dolPool(data) {
  const m = data.m, pool = [];
  for (const tf of ['H1', 'H4', 'D1']) {
    const { bars } = data.tf[tf];
    for (const p of L.pivots(bars, PIV_N[tf])) {
      let sweep = Infinity;
      for (let j = p.i + 1; j < bars.length; j++) {
        if (p.high ? bars[j].h > p.price : bars[j].l < p.price) {
          for (let i = bars[j].i0; i <= bars[j].i1; i++) if (p.high ? m.h[i] > p.price : m.l[i] < p.price) { sweep = m.t[i]; break; }
          break;
        }
      }
      pool.push({ high: p.high, price: p.price, known_t: p.known_t, sweep_t: sweep });
    }
  }
  return pool;
}
// DOL gần nhất phía trước giá e theo chiều dir, đã biết và chưa bị quét tại t.
function nearestDol(pool, t, dir, e) {
  let best = null;
  for (const d of pool) {
    if (d.known_t > t || d.sweep_t < t || d.high !== (dir > 0)) continue;
    if (dir > 0 ? d.price > e && (best === null || d.price < best) : d.price < e && (best === null || d.price > best)) best = d.price;
  }
  return best;
}

export function signals(data, levels, cfg = {}) {
  const m = data.m, { bars: m5, atr: a5 } = data.tf.M5;
  const entry = cfg.entry ?? 'rej', later = cfg.later ?? 'mid', buf = cfg.buf ?? 0.3, tpMode = cfg.tp ?? 'dol';
  const maxTests = cfg.maxTests ?? 3, maxMin = cfg.maxMin ?? 1440, SPREAD = L.COST.spread;
  const pool = tpMode === 'dol' ? dolPool(data) : null;
  const sigs = [];
  let skippedTouchSl = 0;
  const makeSig = (Lv, t, e, sl, testNo, extraTags = {}) => {
    const dir = Lv.side, r = Math.abs(e - sl);
    let tp = e + dir * 2 * r, tpTag = '2R';
    if (pool) { const d = nearestDol(pool, t, dir, e); if (d !== null && Math.abs(d - e) >= 1.5 * r) { tp = d; tpTag = 'dol'; } }
    sigs.push({ t, dir, sl, tp, maxMin, entry_ref: e, rank: RANK[Lv.tf], testNo,
      tags: { tf: Lv.tf, lan: testNo, tp: tpTag, str: Lv.tags.str, ...extraTags } });
  };
  for (const Lv of levels) {
    const s = Lv.side, near = s > 0 ? Lv.hi : Lv.lo, tip = Lv.tip;
    let k = L.lastClosed(m5, Lv.known_t) + 1;
    let armed = false, inTest = false, tests = 0, done = false, markK = -1, ext = 0, mark = 0;
    for (; k < m5.length && m5[k].close_t <= Lv.expire_t && tests <= maxTests; k++) {
      const b = m5[k];
      const outside = s > 0 ? b.l > near : b.h < near;
      if (!armed) { if (outside) armed = true; continue; }
      if (!inTest) {
        if (outside) continue;
        if (tests >= maxTests) break;
        inTest = true; done = false; markK = -1; ext = s > 0 ? Infinity : -Infinity;
        mark = tests === 0 || later === 'tip' ? tip : Lv.mid;
        tests++;
      } else if (outside) { inTest = false; continue; }         // lần kiểm tra kết thúc, giá đã ở hẳn ngoài vùng: sẵn sàng lần sau
      const testNo = tests - 1;
      if (done) continue;
      const reach = s > 0 ? b.l <= mark : b.h >= mark;
      if (entry === 'm1touch' && markK < 0 && reach) {
        // nến M1 đầu tiên chạm mốc; chỉ dùng M1 tới hết nến đó và ATR M5 của nến đã đóng trước
        const atrPrev = k > 0 ? a5[k - 1] : a5[k];
        let e2 = ext;
        for (let i = b.i0; i <= b.i1; i++) {
          e2 = s > 0 ? Math.min(e2, m.l[i]) : Math.max(e2, m.h[i]);
          if (s > 0 ? m.l[i] <= mark : m.h[i] >= mark) {
            const sl = s > 0 ? Math.min(tip, e2) - buf * atrPrev : Math.max(tip, e2) + buf * atrPrev + SPREAD;
            const slHit = s > 0 ? m.l[i] <= sl : m.h[i] + SPREAD >= sl;
            if (slHit) skippedTouchSl++;
            else makeSig(Lv, m.t[i] + MIN, m.c[i], sl, testNo, { vao: 'm1touch' });
            break;
          }
        }
        done = true; markK = k;
        continue;
      }
      ext = s > 0 ? Math.min(ext, b.l) : Math.max(ext, b.h);
      const eps = 0.1 * a5[k];
      if (s > 0 ? b.c < tip - eps : b.c > tip + eps) { done = true; continue; } // phá trong một nhịp: hủy lần kiểm tra
      if (markK < 0 && reach) markK = k;
      if (markK < 0) continue;
      if (k - markK > 2) { done = true; continue; }
      const rej = s > 0 ? b.c > mark && b.c >= b.o : b.c < mark && b.c <= b.o;
      if (!rej) continue;
      const sl = s > 0 ? Math.min(tip, ext) - buf * a5[k] : Math.max(tip, ext) + buf * a5[k] + SPREAD;
      makeSig(Lv, b.close_t, b.c, sl, testNo, { vao: 'rej' });
      done = true;
    }
  }
  if (entry === 'm1touch') console.error(`[owner_wick_htf] m1touch: bỏ ${skippedTouchSl} lần chạm vì nến M1 chạm mốc đã chạm luôn dừng lỗ`);
  // gộp: cùng t, cùng chiều → giữ khung lớn hơn, rồi lần kiểm tra sớm hơn
  const best = new Map();
  for (const x of sigs) {
    const key = x.t + ':' + x.dir, o = best.get(key);
    if (!o || x.rank > o.rank || (x.rank === o.rank && x.testNo < o.testNo)) best.set(key, x);
  }
  const merged = [...best.values()].sort((a, b) => a.t - b.t);
  console.error(`[owner_wick_htf] lệnh: ${sigs.length} trước gộp, ${merged.length} sau gộp`);
  return merged.map(({ rank, testNo, ...x }) => x);
}
