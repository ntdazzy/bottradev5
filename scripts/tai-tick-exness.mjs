// Tải tick Exness từ kho công khai ticks.ex2archive.com theo tháng, đổi sang file nhị phân theo ngày
// vào data/exness/<mã>/tick/YYYY-MM-DD.bin (thư mục data/ không đưa lên Git). Cùng định dạng tick của tai-nen-dukascopy.mjs:
// 10 byte mỗi tick: Int32LE mili giây trong ngày (UTC), Int32LE bid×1000, Int16LE (ask−bid)×1000.
// Dùng: node scripts/tai-tick-exness.mjs [--ma XAUUSDm] [--tu YYYY-MM] [--den YYYY-MM]
// Kho chỉ có mã thường (XAUUSD, XAUUSDm...), không có XAUUSD247m. Chênh giá trong kho có thể là số làm tròn, không phải chênh thật của tài khoản.
// Không tải từ 07/2026: phần 07–09/2026 là dữ liệu khóa (SPEC 24.6). Chạy lại sẽ bỏ qua tháng đã xong. Cần curl và unzip.
import fs from 'fs';
import path from 'path';
import readline from 'readline';
import { execFileSync } from 'child_process';

const LOCK = '2026-07';
const args = process.argv.slice(2), opt = {};
for (let i = 0; i < args.length; i += 2) opt[args[i].replace(/^--/, '')] = args[i + 1];
const sym = opt.ma || 'XAUUSDm', from = opt.tu || '2023-01', to = opt.den || '2026-06';
if (!/^\d{4}-\d{2}$/.test(from) || !/^\d{4}-\d{2}$/.test(to) || from > to) {
  console.error('Dùng: node scripts/tai-tick-exness.mjs [--ma XAUUSDm] [--tu YYYY-MM] [--den YYYY-MM]'); process.exit(1);
}
if (to >= LOCK) { console.error(`loi_tham_so: --den ${to} chạm phần khóa từ ${LOCK} (SPEC 24.6)`); process.exit(1); }

const root = path.join('data', 'exness', sym, 'tick'), tmp = path.join('data', 'exness', sym, '.tai');
fs.mkdirSync(root, { recursive: true }); fs.mkdirSync(tmp, { recursive: true });
const months = [];
for (let y = +from.slice(0, 4), m = +from.slice(5); `${y}-${String(m).padStart(2, '0')}` <= to; m === 12 ? (y++, m = 1) : m++) months.push([y, m]);

let done = 0, missing = 0, failed = 0;
for (const [y, m] of months) {
  const mm = String(m).padStart(2, '0'), mark = path.join(root, `.xong_${y}-${mm}`);
  if (fs.existsSync(mark)) continue;
  const zip = path.join(tmp, `${y}-${mm}.zip`);
  const url = `https://ticks.ex2archive.com/ticks/${sym}/${y}/${mm}/Exness_${sym}_${y}_${mm}.zip`;
  let code;
  try { code = execFileSync('curl', ['-sS', '-m', '900', '--retry', '3', '-o', zip, '-w', '%{http_code}', url]).toString(); }
  catch (e) { console.error(`loi_tai: ${sym} ${y}-${mm}: ${e.message}`); failed++; continue; }
  if (code === '404') { console.log(`${sym} ${y}-${mm}: kho không có`); fs.rmSync(zip, { force: true }); fs.writeFileSync(mark, ''); missing++; continue; }
  if (code !== '200') { console.error(`loi_tai: ${sym} ${y}-${mm}: HTTP ${code}`); fs.rmSync(zip, { force: true }); failed++; continue; }
  try { execFileSync('unzip', ['-o', '-q', zip, '-d', tmp]); }
  catch (e) { console.error(`loi_giai_nen: ${sym} ${y}-${mm}: ${e.message}`); fs.rmSync(zip, { force: true }); failed++; continue; }
  const csv = path.join(tmp, `Exness_${sym}_${y}_${mm}.csv`);
  // Dòng: "exness","XAUUSDm","2025-06-01 22:05:00.056Z",bid,ask
  const days = new Map(); let first = true, bad = 0;
  for await (const line of readline.createInterface({ input: fs.createReadStream(csv) })) {
    if (first) { first = false; continue; }
    const p = line.split(','), ts = p[2]?.replace(/"/g, ''), bid = +p[3], ask = +p[4], t = Date.parse(ts?.replace(' ', 'T'));
    if (!Number.isFinite(t) || !(bid > 0) || !(ask >= bid)) { bad++; continue; }
    const day = ts.slice(0, 10); let a = days.get(day); if (!a) days.set(day, a = []);
    a.push(t - Date.parse(day + 'T00:00:00Z'), Math.round(bid * 1000), Math.min(32767, Math.round((ask - bid) * 1000)));
  }
  for (const [day, a] of days) {
    const n = a.length / 3, buf = Buffer.alloc(n * 10);
    for (let i = 0; i < n; i++) { buf.writeInt32LE(a[3 * i], i * 10); buf.writeInt32LE(a[3 * i + 1], i * 10 + 4); buf.writeInt16LE(a[3 * i + 2], i * 10 + 8); }
    fs.writeFileSync(path.join(root, `${day}.bin`), buf);
  }
  fs.rmSync(csv, { force: true }); fs.rmSync(zip, { force: true }); fs.writeFileSync(mark, '');
  done++;
  console.log(`${sym} ${y}-${mm}: ${days.size} ngày${bad ? `, bỏ ${bad} dòng lỗi` : ''}`);
}
console.log(`xong ${sym}: ${done} tháng tải xong, ${missing} tháng kho không có, ${failed} tháng lỗi (chạy lại để tải tiếp)`);
if (failed) process.exit(2);
