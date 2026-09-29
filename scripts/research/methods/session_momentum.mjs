// session_momentum — phá biên khung mở phiên (opening range breakout), mốc đối chứng KHÔNG dựa trên đỉnh/đáy.
// Khung (range) theo giờ UTC cố định (hoặc giờ địa phương nếu dst:true):
//   LDN : 07:00–07:30 UTC (dst: 08:00–08:30 giờ London), biết lúc hết khung, hết phiên 16:00 UTC (dst: +1h mùa đông)
//   NY  : 13:30–14:00 UTC (dst: 09:30–10:00 giờ New York),               hết phiên 20:00 UTC (dst: +1h mùa đông)
//   ASIA: 00:00–07:00 UTC, biết lúc 07:00,                                   hết phiên 16:00 UTC
//   orb: độ dài khung LDN/NY (phút, mặc định 30). Cần ≥ 80% số nến M1 trong khung (bỏ ngày lễ/thiếu dữ liệu).
// Cản báo cho bộ đo: đỉnh khung = kháng cự (side −1), đáy khung = hỗ trợ (side +1), là ĐƯỜNG (lo = hi = giá),
//   known_t = lúc hết khung, expire_t = hết phiên, atr_src = ATR H1 đã đóng lúc known_t. Nhãn: ses, hl.
// Lệnh: trong `win` phút sau khi hết khung (mặc định 120), nến M5 ĐẦU TIÊN đóng trên đỉnh khung → mua, dưới đáy khung → bán.
//   Mỗi phiên mỗi ngày tối đa 1 lệnh. Dừng lỗ: sl='far' → biên đối diện; sl='mid' → giữa khung. Chốt lời: rr×rủi ro tính từ giá đóng
//   nến M5 phá (rr=0 → không chốt, đóng lúc hết phiên). Mọi lệnh đóng muộn nhất lúc hết phiên (maxMin).
//   Nhãn lệnh: ses, dir (mua/ban), wb = bề rộng khung so với trung vị 20 phiên CÙNG LOẠI TRƯỚC ĐÓ (hep < 0,8×, rong > 1,25×, còn lại vua).
//
// KẾ HOẠCH 8 CẤU HÌNH (ghi trước khi chạy):
//   C1 {ses:[LDN,NY], sl:far, rr:2}   C2 {ses:[LDN,NY], sl:mid, rr:2}   C3 {ses:[LDN,NY], sl:far, rr:0}   C4 {ses:[LDN,NY], sl:mid, rr:1.5}
//   C5 {ses:[ASIA], sl:mid, rr:2}     C6 {ses:[ASIA], sl:mid, rr:0}      C7 = C1 + dst:true                  C8 = C1 + orb:15
// LUẬT ĐÓNG BĂNG (ghi trước khi xem kết quả):
//   B1 (chất lượng cản): bộ cản của cấu hình "đạt" nếu nhóm tat_ca có diff ≥ +3 và diff − ci95 > 0. Nếu có bộ cản đạt, chỉ chọn trong các
//      cấu hình dùng bộ cản đạt có diff cao nhất.
//   B2 (lệnh): trong nhóm còn lại, chọn cấu hình có (meanR − random.meanR) lớn nhất trong các cấu hình có ≥ 200 lệnh (không có cái nào
//      đủ 200 thì xét tất cả). Nếu hai cấu hình đầu cách nhau < 0,02R → chọn cái gần mặc định sách C1 hơn (ít thay đổi so với C1).
import * as L from '../lib.mjs';

const DEF = { ses: ['LDN', 'NY'], sl: 'far', rr: 2, win: 120, orb: 30, dst: false };
const cfgOf = cfg => ({ ...DEF, ...cfg });
const MIN = L.MIN, HOUR = 3600000;

// Chủ nhật cuối của tháng `mo` (0-based) và Chủ nhật thứ n, trả mốc 00:00 UTC của ngày đó.
const lastSunday = (y, mo) => { const d = new Date(Date.UTC(y, mo + 1, 0)); return Date.UTC(y, mo, d.getUTCDate() - d.getUTCDay()); };
const nthSunday = (y, mo, n) => { const d = new Date(Date.UTC(y, mo, 1)); return Date.UTC(y, mo, 1 + ((7 - d.getUTCDay()) % 7) + 7 * (n - 1)); };
// Mùa đông (giờ chuẩn) → khung dời +60 phút UTC.
function winterShift(ses, t) {
  const y = new Date(t).getUTCFullYear();
  if (ses === 'LDN') return (t >= lastSunday(y, 2) + HOUR && t < lastSunday(y, 9) + HOUR) ? 0 : 60;
  if (ses === 'NY') return (t >= nthSunday(y, 2, 2) + 7 * HOUR && t < nthSunday(y, 10, 1) + 6 * HOUR) ? 0 : 60;
  return 0;
}

function sessionDefs(c) {
  return {
    LDN: { start: 7 * 60, len: c.orb, end: 16 * 60 },
    NY: { start: 13 * 60 + 30, len: c.orb, end: 20 * 60 },
    ASIA: { start: 0, len: 420, end: 16 * 60 },
  };
}

// Tính các khung mở phiên. Chỉ dùng nến M1 trong khung; bề rộng tham chiếu (wb) chỉ dùng các phiên TRƯỚC.
function ranges(data, c) {
  const { m } = data, h1 = data.tf.H1, defs = sessionDefs(c), out = [];
  const hist = {};
  for (const D of data.tf.D1.bars) {
    for (const ses of c.ses) {
      const d = defs[ses];
      const sh = c.dst ? winterShift(ses, D.t + d.start * MIN) : 0;
      const t0 = D.t + (d.start + sh) * MIN, t1 = t0 + d.len * MIN, tEnd = D.t + (d.end + sh) * MIN;
      let h = -Infinity, l = Infinity, n = 0;
      for (let i = L.idxAt(m, t0); i < m.n && m.t[i] < t1; i++) { if (m.h[i] > h) h = m.h[i]; if (m.l[i] < l) l = m.l[i]; n++; }
      if (n < Math.ceil(0.8 * d.len)) continue;
      const w = h - l;
      const past = (hist[ses] ||= []);
      let wb = 'na';
      if (past.length >= 10) {
        const s = past.slice(-20).sort((a, b) => a - b), med = s[Math.floor((s.length - 1) / 2)];
        wb = w < 0.8 * med ? 'hep' : w > 1.25 * med ? 'rong' : 'vua';
      }
      past.push(w);
      const k = L.lastClosed(h1.bars, t1);
      out.push({ key: ses + D.t, ses, hi: h, lo: l, known_t: t1, end_t: tEnd, aH1: k >= 0 ? h1.atr[k] : 0, wb });
    }
  }
  return out;
}

export function levels(data, cfg = {}) {
  const c = cfgOf(cfg), out = [];
  for (const R of ranges(data, c)) {
    for (const [hl, side, price] of [['H', -1, R.hi], ['L', 1, R.lo]]) {
      out.push({ id: R.key + hl, side, lo: price, hi: price, known_t: R.known_t, expire_t: R.end_t, atr_src: R.aH1,
        tags: { ses: R.ses, hl }, rg: R });
    }
  }
  return out;
}

export function signals(data, levels, cfg = {}) {
  const c = cfgOf(cfg);
  const m5 = data.tf.M5.bars;
  const seen = new Set(), sigs = [];
  for (const Lv of levels) {
    const R = Lv.rg;
    if (!R || seen.has(R.key)) continue;
    seen.add(R.key);
    const tLast = Math.min(R.known_t + c.win * MIN, R.end_t);
    for (let k = L.lastClosed(m5, R.known_t) + 1; k < m5.length && m5[k].close_t <= tLast; k++) {
      const b = m5[k];
      const dir = b.c > R.hi ? 1 : b.c < R.lo ? -1 : 0;
      if (!dir) continue;
      const sl = c.sl === 'mid' ? (R.hi + R.lo) / 2 : (dir > 0 ? R.lo : R.hi);
      const risk = Math.abs(b.c - sl);
      const maxMin = Math.round((R.end_t - b.close_t) / MIN);
      if (maxMin > 0) sigs.push({ t: b.close_t, dir, sl, tp: c.rr > 0 ? b.c + dir * c.rr * risk : null, maxMin, entry_ref: b.c,
        tags: { ses: R.ses, dir: dir > 0 ? 'mua' : 'ban', wb: R.wb } });
      break; // chỉ lần phá đầu tiên của phiên
    }
  }
  return sigs;
}
