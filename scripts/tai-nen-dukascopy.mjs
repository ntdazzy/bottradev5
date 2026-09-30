// Tải nến và tick từ Dukascopy để nghiên cứu, lưu vào data/dukascopy/<mã>/ ở gốc dự án (thư mục data/ không đưa lên Git).
// Dùng: node scripts/tai-nen-dukascopy.mjs <m1|h1|tick> [--ma xauusd] [--tu YYYY-MM-DD] [--den YYYY-MM-DD]
//   m1:   mỗi ngày một file m1/YYYY-MM-DD.csv, dòng "t,o,h,l,c,v" (giá bid, t = mili giây UTC lúc mở nến).
//   h1:   mỗi năm một file h1/YYYY.csv, dòng "t,o,h,l,c" (giá bid). File năm thiếu đầu/cuối khoảng cần tải sẽ được tải lại.
//   tick: mỗi ngày một file tick/YYYY-MM-DD.bin, 10 byte mỗi tick: Int32LE mili giây trong ngày,
//         Int32LE bid×1000, Int16LE (ask−bid)×1000. Chỉ cho mã có 3 chữ số thập phân (xauusd, xagusd).
// Không tải từ 2026-07-01 trở đi: phần 07–09/2026 là dữ liệu khóa (SPEC 24.6). Chạy lại sẽ bỏ qua file đã có.
// Cần gói dukascopy-node: npm install --no-save dukascopy-node@1.50.0
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const LOCK = '2026-07-01', DAY = 86400000, TICK_SYMS = ['xauusd', 'xagusd'];
const fail = msg => { console.error(`loi_tham_so: ${msg}`); process.exit(1); };
const [mode, ...rest] = process.argv.slice(2);
if (!['m1', 'h1', 'tick'].includes(mode)) fail('Dùng: node scripts/tai-nen-dukascopy.mjs <m1|h1|tick> [--ma xauusd] [--tu YYYY-MM-DD] [--den YYYY-MM-DD]');
const opt = {};
for (let i = 0; i < rest.length; i += 2) {
  const key = rest[i]?.replace(/^--/, '');
  if (!['ma', 'tu', 'den'].includes(key) || rest[i + 1] === undefined) fail(`tham số không hợp lệ "${rest[i]}"; chỉ nhận --ma, --tu, --den kèm giá trị`);
  opt[key] = rest[i + 1];
}
const isDate = s => /^\d{4}-\d{2}-\d{2}$/.test(s) && new Date(s + 'T00:00:00Z').toISOString().slice(0, 10) === s;
const sym = (opt.ma || 'xauusd').toLowerCase();
const from = opt.tu || (mode === 'h1' ? '2003-01-01' : '2025-01-01');
const to = opt.den || LOCK;
if (!/^[a-z0-9]+$/.test(sym)) fail(`--ma "${opt.ma}" không hợp lệ`);
if (!isDate(from) || !isDate(to)) fail('--tu và --den phải là ngày thật dạng YYYY-MM-DD');
if (to > LOCK) fail(`--den ${to} vượt ${LOCK}; phần 07–09/2026 đang khóa (SPEC 24.6)`);
if (!(from < to)) fail(`--tu ${from} phải trước --den ${to}`);
if (mode === 'tick' && !TICK_SYMS.includes(sym)) fail(`tick lưu giá ×1000 nên chỉ dùng cho ${TICK_SYMS.join(', ')}`);

let getHistoricalRates;
try { ({ getHistoricalRates } = await import('dukascopy-node')); }
catch { fail('thiếu gói: chạy "npm install --no-save dukascopy-node@1.50.0" ở thư mục dự án rồi chạy lại'); }

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'data', 'dukascopy', sym, mode);
fs.mkdirSync(root, { recursive: true });
const sleep = ms => new Promise(r => setTimeout(r, ms));
const writeAtomic = (file, data) => { fs.writeFileSync(file + '.tmp', data); fs.renameSync(file + '.tmp', file); };

// Tải một khoảng. retryCount > 0: thư viện thử lại mỗi giờ lỗi (kể cả 429) 3 lần rồi báo lỗi, không coi là giờ rỗng;
// giờ trống thật (giờ nghỉ, cuối tuần) vẫn nhận là rỗng (retryOnEmpty: false). Ngoài ra thử lại cả khoảng 5 lần;
// vẫn lỗi thì trả null, không ghi file. volumes bật cho m1 và h1 để thư viện bỏ nến phẳng tự chèn vào giờ đóng cửa.
async function fetchRange(start, end, timeframe) {
  for (let a = 1; a <= 5; a++) {
    try {
      return await getHistoricalRates({ instrument: sym, dates: { from: new Date(start), to: new Date(end) }, timeframe, format: 'array',
        priceType: 'bid', volumes: timeframe !== 'tick', retryOnEmpty: false, retryCount: 3, pauseBetweenRetriesMs: 2000,
        batchSize: 2, pauseBetweenBatchesMs: 1000 });                   // tải chậm để tránh bị Dukascopy giới hạn (429)
    } catch (e) {
      if (!(e instanceof Error)) fail(`thư viện từ chối yêu cầu (${JSON.stringify(e)}); kiểm tra --ma và ngày`);
      console.error(`loi_tai: ${sym} ${timeframe} ${new Date(start).toISOString().slice(0, 10)} lần ${a}: ${e.message}`);
      await sleep((/429/.test(e.message) ? 15000 : 3000) * a);        // 429 = bị giới hạn tần suất, chờ lâu hơn
    }
  }
  return null;
}
// File năm H1 đủ khi nến đầu và nến cuối nằm trong 7 ngày quanh hai biên của khoảng cần tải.
function h1Complete(file, start, end) {
  const rows = fs.readFileSync(file, 'utf8').trim().split('\n').filter(Boolean);
  if (!rows.length) return false;
  const first = +rows[0].split(',')[0], last = +rows[rows.length - 1].split(',')[0];
  return first <= start + 7 * DAY && last >= end - 7 * DAY;
}

let ok = 0, empty = 0, failed = 0;
if (mode === 'h1') {
  for (let y = +from.slice(0, 4); y <= +to.slice(0, 4); y++) {
    const file = path.join(root, `${y}.csv`);
    const start = Math.max(Date.parse(`${y}-01-01T00:00:00Z`), Date.parse(from + 'T00:00:00Z'));
    const end = Math.min(Date.parse(`${y + 1}-01-01T00:00:00Z`), Date.parse(to + 'T00:00:00Z'));
    if (start >= end || (fs.existsSync(file) && h1Complete(file, start, end))) continue;
    const rows = await fetchRange(start, end, 'h1');
    if (!rows) { failed++; continue; }
    writeAtomic(file, rows.map(r => r.slice(0, 5).join(',')).join('\n') + (rows.length ? '\n' : ''));
    rows.length ? ok++ : empty++;
    console.log(`${sym} h1 ${y}: ${rows.length} nến`);
  }
} else {
  for (let t = Date.parse(from + 'T00:00:00Z'); t < Date.parse(to + 'T00:00:00Z'); t += DAY) {
    const wd = new Date(t).getUTCDay(); if (wd === 6) continue;         // thứ Bảy không có phiên
    const day = new Date(t).toISOString().slice(0, 10);
    const file = path.join(root, mode === 'm1' ? `${day}.csv` : `${day}.bin`);
    if (fs.existsSync(file)) continue;
    const rows = await fetchRange(t, t + DAY, mode === 'm1' ? 'm1' : 'tick');
    if (!rows) { failed++; continue; }
    if (mode === 'm1') writeAtomic(file, rows.map(r => r.join(',')).join('\n') + (rows.length ? '\n' : ''));
    else {
      const buf = Buffer.alloc(rows.length * 10);           // tick: [t, ask, bid, askVolume, bidVolume]
      rows.forEach((r, i) => {
        buf.writeInt32LE(r[0] - t, i * 10);
        buf.writeInt32LE(Math.round(r[2] * 1000), i * 10 + 4);
        buf.writeInt16LE(Math.min(32767, Math.round((r[1] - r[2]) * 1000)), i * 10 + 8);
      });
      writeAtomic(file, buf);
    }
    rows.length ? ok++ : empty++;
    // Ngày thường trống hẳn hoặc thiếu giờ trong 00–20h UTC: báo để kiểm (ngày lễ thì bình thường; nếu không, xóa file rồi tải lại)
    const hours = new Set(rows.map(r => Math.floor((r[0] - t) / 3600000)));
    const gaps = wd >= 1 && wd <= 5 ? [...Array(21).keys()].filter(h => !hours.has(h)) : [];
    if (gaps.length) console.error(`canh_bao_thieu_gio: ${sym} ${mode} ${day} không có dữ liệu giờ UTC ${gaps.length === 21 ? '00–20 (cả ngày)' : gaps.join(', ')}`);
    if ((ok + empty) % 20 === 0) console.log(`${sym} ${mode} tới ${day}: ${ok} ngày có dữ liệu, ${empty} ngày trống`);
  }
}
console.log(`xong ${sym} ${mode}: ${ok} file có dữ liệu, ${empty} file trống (ngày nghỉ), ${failed} lỗi (chạy lại để tải tiếp)`);
if (failed) process.exit(2);
