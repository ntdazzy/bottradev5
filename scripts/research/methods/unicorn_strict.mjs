// unicorn_strict.mjs — ICT Unicorn làm CHẶT theo docs/research/14-ict-unicorn-model.md mục 5.1 (khung M5 và M15, mỗi khung riêng).
// Mọi luật viết cho MUA trong "không gian mua"; BÁN = cùng luật trên giá lật dấu (o'=-o, h'=-l, l'=-h, c'=-c).
//  1. DOL: cặp đỉnh pivot (L.pivots N) bằng nhau tương đối |ΔH| <= tolAtr·ATR(khung, lúc đỉnh sau xác nhận), cách nhau <= pairSpan nến,
//     không nến nào ở giữa vượt mức DOL = max(hai đỉnh). Biết lúc đỉnh sau xác nhận. Bị quét = nến M1 đầu tiên có H > mức (râu).
//     Hết hạn sau dolLifeDays ngày. DOL phải có trước khi nến X đóng và chưa bị quét lúc vùng được biết.
//  2. Nhánh thao túng: dãy pivot xen kẽ (cùng loại liên tiếp giữ cái cực hơn); khi có đáy mới X: 3 điểm cuối [P đáy, G đỉnh, X đáy], X < P
//     (quét đáy cũ, chạy XA khỏi DOL ở trên).
//  3. Breaker k = nến tăng (C>O) cuối cùng trong [G, X) — "nến ngược màu cuối trước cực trị quét". BB = [L(k), H(k)] (cả râu, 1 nến).
//  4. Dịch chuyển j: nến đầu tiên trong (X, X+maxDisp] đóng > H(k) với thân tăng >= dispAtr·ATR(j-1); trước đó không nến nào thủng X.
//  5. FVG của chính nến dịch chuyển: c1=j-1, c2=j, c3=j+1, cần L(j+1) > H(j-1): FVG = [H(j-1), L(j+1)].
//  6. Unicorn: [max(L(k),H(j-1)), min(H(k),L(j+1))] có chiều cao > 0. Vùng = HỢP BB∪FVG. known_t = max(X xác nhận, j+1 đóng).
//  7. SL = thân dưới thấp nhất của nhánh thao túng (nến G..X), không đệm. TP = DOL gần nhất phía trên mép gần. Bỏ nếu (TP−vào)/(vào−SL) < 2
//     tính ở mép gần (giá vào của tài liệu). Vùng hết hạn: lifeBars nến khung, hoặc lúc DOL bị quét (lệnh chờ hủy), hoặc hết phiên NY.
//  8. Phiên: sess='ny' chỉ giữ vùng biết trong 13:00–20:00 UTC và hủy lúc 20:00 UTC cùng ngày; sess='all' mọi giờ (nhãn sess=ny/off).
// Lệnh (chỉ lần thử lại đầu, sau khi giá đã ở hẳn trên mép gần; trước đó mà M1 đóng dưới mép xa hoặc chạm SL thì vùng chết):
//  entry='limit': lệnh chờ ở mép gần; mô phỏng bằng vào ở giá mở M1 kế sau nến M1 chạm mép gần (quy ước runner, như s411_strict).
//  entry='rej'  : từ nến chứa lần chạm, trong rejWait nến khung nhỏ (M1 cho vùng M5, M5 cho vùng M15): nến đóng lại trên mép gần thì vào
//                 ở giá đóng đó; đóng dưới mép xa hoặc chạm SL trước thì bỏ. Kiểm lại ≥ 2R với giá vào thật, DOL chưa bị quét.
//  Không quản lý lệnh; giữ tối đa maxMin phút (giới hạn kỹ thuật).
//
// 8 CẤU HÌNH ĐĂNG KÝ TRƯỚC (2×2×2, maxTouches=1): N ∈ {3,2} × sess ∈ {all,ny} × entry ∈ {limit,rej}
//   C1 N3 all limit | C2 N3 all rej | C3 N3 ny limit | C4 N3 ny rej | C5 N2 all limit | C6 N2 all rej | C7 N2 ny limit | C8 N2 ny rej
// LUẬT ĐÓNG BĂNG (ghi TRƯỚC khi chạy bất kỳ cấu hình nào):
//   Bước 1 (chất lượng cản): 4 bộ cản (N×sess). Chọn bộ có (diff − ci95) nhóm tat_ca lớn nhất trong các bộ có n_real ≥ 100;
//          không bộ nào đạt n_real ≥ 100 thì chọn bộ có n_real lớn nhất.
//   Bước 2 (lệnh): trong 2 cấu hình của bộ đã chọn, chọn (meanR − random.meanR) lớn nhất nếu cả hai có ≥ 30 lệnh;
//          chỉ một cái có ≥ 30 lệnh thì chọn cái đó; không cái nào thì chọn 'limit' (giá vào của tài liệu).
import * as L from '../lib.mjs';

const DEF = {
  tfs: ['M5', 'M15'], N: 3, tolAtr: 0.1, pairSpan: 100, dolLifeDays: 5, dispAtr: 1.0, maxDisp: 10,
  minRR: 2, lifeBars: 48, sess: 'all', nyFrom: 13, nyTo: 20, entry: 'limit', rejWait: 6, maxMin: 1440,
};
const DAY = 86400000;
export const DBG = {}; const dbg = k => { DBG[k] = (DBG[k] || 0) + 1; };

const flip = bars => bars.map(b => ({ t: b.t, close_t: b.close_t, o: -b.o, h: -b.l, l: -b.h, c: -b.c, i0: b.i0, i1: b.i1 }));
const hourOf = t => (t % DAY) / 3600000;
const inNY = (t, cfg) => { const h = hourOf(t); return h >= cfg.nyFrom && h < cfg.nyTo; };
const nyEnd = (t, cfg) => Math.floor(t / DAY) * DAY + cfg.nyTo * 3600000;
// M1 trong không gian mua theo chiều d
const m1 = (m, d) => d > 0
  ? { h: i => m.h[i], l: i => m.l[i], c: i => m.c[i], o: i => m.o[i] }
  : { h: i => -m.l[i], l: i => -m.h[i], c: i => -m.c[i], o: i => -m.o[i] };

// DOL: cặp đỉnh bằng nhau tương đối (không gian mua). Trả mảng {level, known_t, end} sắp theo known_t.
function dols(m, a, tb, atr, cfg) {
  const piv = L.pivots(tb, cfg.N).filter(p => p.high), out = [];
  for (let x = 0; x < piv.length; x++) {
    const p = piv[x], tol = cfg.tolAtr * atr[p.i + cfg.N];
    let runMax = -Infinity, lastI = p.i;
    for (let y = x - 1; y >= 0; y--) {
      const q = piv[y];
      if (p.i - q.i > cfg.pairSpan) break;
      for (let k = q.i + 1; k < lastI; k++) if (tb[k].h > runMax) runMax = tb[k].h; // max râu các nến giữa q và p
      lastI = q.i + 1;
      if (runMax > p.price + tol) break;
      const lv = Math.max(p.price, q.price);
      if (Math.abs(p.price - q.price) <= tol && runMax <= lv) {
        out.push({ level: lv, known_t: p.known_t });
        break; // mỗi đỉnh mới: cặp với đỉnh bằng nhau gần nhất
      }
    }
  }
  // lúc bị quét (M1 râu vượt mức) hoặc hết hạn
  const life = cfg.dolLifeDays * DAY;
  for (const D of out) {
    let end = D.known_t + life;
    for (let i = L.idxAt(m, D.known_t); i < m.n && m.t[i] < end; i++) if (a.h(i) > D.level) { end = m.t[i]; break; }
    D.end = end;
  }
  return out.sort((u, v) => u.known_t - v.known_t);
}

function setupsFor(data, tfName, d, cfg) {
  const { m } = data, { bars, atr } = data.tf[tfName];
  const tb = d > 0 ? bars : flip(bars), a = m1(m, d), tfMs = L.TF[tfName] * L.MIN, N = cfg.N;
  const D = dols(m, a, tb, atr, cfg);
  const out = [], seen = new Set(), seq = [];
  for (const p of L.pivots(tb, N)) {
    const last = seq[seq.length - 1];
    if (last && last.high === p.high) {
      if (p.high ? p.price > last.price : p.price < last.price) seq[seq.length - 1] = p; else continue;
    } else seq.push(p);
    if (p.high || seq.length < 3) continue;
    const [P, G, X] = seq.slice(-3);
    dbg(tfName + ' 0_pivot_low');
    if (!(X.price < P.price)) continue;                       // quét đáy cũ
    dbg(tfName + ' 1_sweep');
    let k = -1;
    for (let i = X.i - 1; i >= G.i; i--) if (tb[i].c > tb[i].o) { k = i; break; }
    if (k < 0) continue;
    dbg(tfName + ' 2_breaker');
    const bbLo = tb[k].l, bbHi = tb[k].h;
    let j = -1;
    for (let i = X.i + 1; i <= X.i + cfg.maxDisp && i + 1 < tb.length; i++) {
      if (tb[i].l < X.price) break;                           // nhánh chưa xong
      if (tb[i].c > bbHi && tb[i].c - tb[i].o >= cfg.dispAtr * atr[i - 1]) { j = i; break; }
    }
    if (j < 0) continue;
    dbg(tfName + ' 3_displacement');
    const fLo = tb[j - 1].h, fHi = tb[j + 1].l;
    if (!(fHi > fLo)) continue;
    dbg(tfName + ' 4_fvg');
    const oLo = Math.max(bbLo, fLo), oHi = Math.min(bbHi, fHi);
    if (!(oHi > oLo)) continue;
    dbg(tfName + ' 5_overlap');
    const key = k + ':' + j;
    if (seen.has(key)) continue;
    seen.add(key);
    const zLo = Math.min(bbLo, fLo), zHi = Math.max(bbHi, fHi);
    const known_t = Math.max(X.known_t, tb[j + 1].close_t);
    let sl = Infinity;
    for (let i = G.i; i <= X.i; i++) sl = Math.min(sl, tb[i].o, tb[i].c);
    if (!(sl < zHi)) continue;
    // DOL gần nhất phía trên mép gần: có trước khi X đóng, chưa quét lúc known_t
    let dol = null;
    for (const Dv of D) {
      if (Dv.known_t > tb[X.i].close_t) break;
      if (Dv.end + L.MIN <= known_t || Dv.level <= zHi) continue;
      if (!dol || Dv.level < dol.level) dol = Dv;
    }
    if (!dol) continue;
    dbg(tfName + ' 6_dol');
    const rr = (dol.level - zHi) / (zHi - sl);
    if (rr < cfg.minRR) continue;
    dbg(tfName + ' 7_rr2');
    const sessTag = inNY(known_t, cfg) ? 'ny' : 'off';
    if (cfg.sess === 'ny' && sessTag !== 'ny') continue;
    dbg(tfName + ' 8_session');
    let expire_t = Math.min(known_t + cfg.lifeBars * tfMs, dol.end + L.MIN); // DOL bị quét: biết lúc nến M1 quét đóng
    if (cfg.sess === 'ny') expire_t = Math.min(expire_t, nyEnd(known_t, cfg));
    if (!(expire_t > known_t)) continue;
    const back = x => d * x;
    const lo = d > 0 ? zLo : -zHi, hi = d > 0 ? zHi : -zLo;
    out.push({ id: `${tfName}${d > 0 ? 'b' : 's'}${j}`, side: d, lo, hi, known_t, expire_t, atr_src: atr[j],
      tags: { tf: tfName, dir: d > 0 ? 'buy' : 'sell', sess: sessTag },
      _d: d, _tf: tfName, _zLo: zLo, _zHi: zHi, _sl: sl, _tp: dol.level, _dolEnd: dol.end, _slO: back(sl), _tpO: back(dol.level) });
  }
  return out;
}

export function levels(data, cfg0 = {}) {
  const cfg = { ...DEF, ...cfg0 };
  let out = [];
  for (const tf of cfg.tfs) for (const d of [1, -1]) out = out.concat(setupsFor(data, tf, d, cfg));
  return out.sort((u, v) => u.known_t - v.known_t);
}

export function signals(data, levels, cfg0 = {}) {
  const cfg = { ...DEF, ...cfg0 };
  const { m } = data, sigs = [];
  for (const Lv of levels) {
    const d = Lv._d, a = m1(m, d), { _zLo: zLo, _zHi: zHi, _sl: sl, _tp: tp } = Lv;
    const iEnd = Math.min(m.n, L.idxAt(m, Lv.expire_t));
    let armed = false, iT = -1;
    for (let i = L.idxAt(m, Lv.known_t); i < iEnd; i++) {
      if (!armed) {
        if (a.c(i) < zLo || a.l(i) <= sl) break;               // vùng chết trước khi giá quay lên trên
        if (a.l(i) > zHi) armed = true;
        continue;
      }
      if (a.l(i) <= zHi) { iT = i; break; }
    }
    if (iT < 0) continue;
    const back = x => d * x, sess = cfg.sess === 'ny';
    const push = (t, entryB) => {
      if (sess && t > nyEnd(Lv.known_t, cfg)) return;
      if (!(t < Lv._dolEnd + L.MIN)) return;                  // DOL đã bị quét (nến M1 quét đã đóng lúc t)
      if ((tp - entryB) / (entryB - sl) < cfg.minRR) return;
      sigs.push({ t, dir: d, sl: back(sl), tp: back(tp), maxMin: cfg.maxMin, entry_ref: back(entryB),
        tags: { ...Lv.tags, entry: cfg.entry } });
    };
    if (cfg.entry === 'limit') { push(m.t[iT] + L.MIN, zHi); continue; }
    // rej: khung nhỏ M1 (vùng M5) hoặc M5 (vùng M15)
    if (Lv._tf === 'M5') {
      for (let w = 0, i = iT; w < cfg.rejWait && i < m.n; w++, i++) {
        if (a.l(i) <= sl || a.c(i) < zLo) break;
        if (a.c(i) > zHi) { push(m.t[i] + L.MIN, a.c(i)); break; }
      }
    } else {
      const m5 = data.tf.M5.bars;
      let k = L.lastClosed(m5, m.t[iT]) + 1;
      for (let w = 0; w < cfg.rejWait && k < m5.length; w++, k++) {
        const b = m5[k], bl = d > 0 ? b.l : -b.h, bc = d * b.c;
        if (bl <= sl || bc < zLo) break;
        if (bc > zHi) { push(b.close_t, bc); break; }
      }
    }
  }
  return sigs;
}
