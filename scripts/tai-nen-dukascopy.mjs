// Tải nến và tick từ Dukascopy để nghiên cứu, lưu vào data/dukascopy/<mã>/ (thư mục data/ không đưa lên Git).
// Dùng: node scripts/tai-nen-dukascopy.mjs <m1|h1|tick> [--ma xauusd] [--tu YYYY-MM-DD] [--den YYYY-MM-DD]
//   m1:   mỗi ngày một file m1/YYYY-MM-DD.csv, dòng "t,o,h,l,c,v" (giá bid, t = mili giây UTC lúc mở nến).
//   h1:   mỗi năm một file h1/YYYY.csv, dòng "t,o,h,l,c" (giá bid).
//   tick: mỗi ngày một file tick/YYYY-MM-DD.bin, 10 byte mỗi tick: Int32LE mili giây trong ngày,
//         Int32LE bid×1000, Int16LE (ask−bid)×1000.
// Không tải từ 2026-07-01 trở đi: phần 07–09/2026 là dữ liệu khóa (SPEC 24.6). Chạy lại sẽ bỏ qua file đã có.
// Cần gói dukascopy-node: npm install --no-save dukascopy-node@1.50.0
import fs from 'fs';
import path from 'path';

const LOCK = '2026-07-01', DAY = 86400000;
const [mode, ...rest] = process.argv.slice(2);
const opt = {};
for (let i = 0; i < rest.length; i += 2) opt[rest[i].replace(/^--/, '')] = rest[i + 1];
if (!['m1', 'h1', 'tick'].includes(mode)) {
  console.error('Dùng: node scripts/tai-nen-dukascopy.mjs <m1|h1|tick> [--ma xauusd] [--tu YYYY-MM-DD] [--den YYYY-MM-DD]');
  process.exit(1);
}
const sym = (opt.ma || 'xauusd').toLowerCase();
const from = opt.tu || (mode === 'h1' ? '2003-01-01' : '2025-01-01');
const to = opt.den || LOCK;
if (to > LOCK) { console.error(`loi_tham_so: --den ${to} vượt ${LOCK}; phần 07–09/2026 đang khóa (SPEC 24.6)`); process.exit(1); }
if (!(from < to)) { console.error(`loi_tham_so: --tu ${from} phải trước --den ${to}`); process.exit(1); }

let getHistoricalRates;
try { ({ getHistoricalRates } = await import('dukascopy-node')); }
catch { console.error('thieu_goi: chạy "npm install --no-save dukascopy-node@1.50.0" ở thư mục dự án rồi chạy lại'); process.exit(1); }

const root = path.join('data', 'dukascopy', sym, mode);
fs.mkdirSync(root, { recursive: true });
const sleep = ms => new Promise(r => setTimeout(r, ms));

// Tải một khoảng; lỗi mạng thử lại 5 lần. Trả null nếu vẫn lỗi (không ghi file để lần sau tải lại).
// Dukascopy đôi khi trả rỗng tạm thời cho một giờ: thư viện tự thử lại giờ rỗng 3 lần (retryOnEmpty) để không mất dữ liệu im lặng.
async function fetchRange(start, end, timeframe) {
  for (let a = 1; a <= 5; a++) {
    try {
      return await getHistoricalRates({ instrument: sym, dates: { from: new Date(start), to: new Date(end) }, timeframe, format: 'array',
        priceType: 'bid', volumes: timeframe === 'm1', retryOnEmpty: true, retryCount: 3, pauseBetweenRetriesMs: 500,
        batchSize: 2, pauseBetweenBatchesMs: 1000 });                  // tải chậm để tránh bị Dukascopy giới hạn (429)
    } catch (e) {
      console.error(`loi_tai: ${sym} ${timeframe} ${new Date(start).toISOString().slice(0, 10)} lần ${a}: ${e.message}`);
      await sleep((/429/.test(e.message) ? 15000 : 3000) * a);   // 429 = bị giới hạn tần suất, chờ lâu hơn
    }
  }
  return null;
}

let ok = 0, empty = 0, failed = 0;
if (mode === 'h1') {
  for (let y = +from.slice(0, 4); y <= +to.slice(0, 4); y++) {
    const file = path.join(root, `${y}.csv`);
    if (fs.existsSync(file)) continue;
    const start = Math.max(Date.parse(`${y}-01-01T00:00:00Z`), Date.parse(from + 'T00:00:00Z'));
    const end = Math.min(Date.parse(`${y + 1}-01-01T00:00:00Z`), Date.parse(to + 'T00:00:00Z'));
    if (start >= end) continue;
    const rows = await fetchRange(start, end, 'h1');
    if (!rows) { failed++; continue; }
    fs.writeFileSync(file, rows.map(r => r.slice(0, 5).join(',')).join('\n') + (rows.length ? '\n' : ''));
    rows.length ? ok++ : empty++;
    console.log(`${sym} h1 ${y}: ${rows.length} nến`);
  }
} else {
  for (let t = Date.parse(from + 'T00:00:00Z'); t < Date.parse(to + 'T00:00:00Z'); t += DAY) {
    if (new Date(t).getUTCDay() === 6) continue;                       // thứ Bảy không có phiên
    const day = new Date(t).toISOString().slice(0, 10);
    const file = path.join(root, mode === 'm1' ? `${day}.csv` : `${day}.bin`);
    if (fs.existsSync(file)) continue;
    const rows = await fetchRange(t, t + DAY, mode === 'm1' ? 'm1' : 'tick');
    if (!rows) { failed++; continue; }
    if (mode === 'm1') fs.writeFileSync(file, rows.map(r => r.join(',')).join('\n') + (rows.length ? '\n' : ''));
    else {
      const buf = Buffer.alloc(rows.length * 10);           // tick: [t, ask, bid, askVolume, bidVolume]
      rows.forEach((r, i) => {
        buf.writeInt32LE(r[0] - t, i * 10);
        buf.writeInt32LE(Math.round(r[2] * 1000), i * 10 + 4);
        buf.writeInt16LE(Math.min(32767, Math.round((r[1] - r[2]) * 1000)), i * 10 + 8);
      });
      fs.writeFileSync(file, buf);
      // Cảnh báo giờ trống trong phiên chính (00–20h UTC, thứ Hai–thứ Sáu) để không thiếu dữ liệu mà không biết
      const wd = new Date(t).getUTCDay(), hours = new Set(rows.map(r => Math.floor((r[0] - t) / 3600000)));
      const gaps = wd >= 1 && wd <= 5 && rows.length ? [...Array(21).keys()].filter(h => !hours.has(h)) : [];
      if (gaps.length) console.error(`canh_bao_thieu_gio: ${sym} tick ${day} không có tick giờ UTC ${gaps.join(', ')} (ngày lễ thì bình thường; nếu không, xóa file và tải lại)`);
    }
    rows.length ? ok++ : empty++;
    if ((ok + empty) % 20 === 0) console.log(`${sym} ${mode} tới ${day}: ${ok} ngày có dữ liệu, ${empty} ngày trống`);
  }
}
console.log(`xong ${sym} ${mode}: ${ok} file có dữ liệu, ${empty} file trống (ngày nghỉ), ${failed} lỗi (chạy lại để tải tiếp)`);
if (failed) process.exit(2);
