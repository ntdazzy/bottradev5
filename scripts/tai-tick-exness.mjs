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
import { fileURLToPath } from 'url';

const LOCK = '2026-07';
const fail = msg => { console.error(`loi_tham_so: ${msg}`); process.exit(1); };
const args = process.argv.slice(2), opt = {};
for (let i = 0; i < args.length; i += 2) {
  const key = args[i]?.replace(/^--/, '');
  if (!['ma', 'tu', 'den'].includes(key) || args[i + 1] === undefined) fail(`tham số không hợp lệ "${args[i]}"; chỉ nhận --ma, --tu, --den kèm giá trị`);
  opt[key] = args[i + 1];
}
const sym = opt.ma || 'XAUUSDm', from = opt.tu || '2023-01', to = opt.den || '2026-06';
const isMonth = s => /^\d{4}-(0[1-9]|1[0-2])$/.test(s);
if (!/^[A-Za-z0-9]+$/.test(sym)) fail(`--ma "${sym}" không hợp lệ`);
if (!isMonth(from) || !isMonth(to) || from > to) fail('Dùng: node scripts/tai-tick-exness.mjs [--ma XAUUSDm] [--tu YYYY-MM] [--den YYYY-MM], tháng 01–12, --tu không sau --den');
if (to >= LOCK) fail(`--den ${to} chạm phần khóa từ ${LOCK} (SPEC 24.6)`);

const base = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'data', 'exness', sym);
const root = path.join(base, 'tick'), tmp = path.join(base, '.tai');
fs.mkdirSync(root, { recursive: true }); fs.mkdirSync(tmp, { recursive: true });
const months = [];
for (let y = +from.slice(0, 4), m = +from.slice(5); `${y}-${String(m).padStart(2, '0')}` <= to; m === 12 ? (y++, m = 1) : m++) months.push([y, m]);

let done = 0, missing = 0, failed = 0;
for (const [y, m] of months) {
  const mm = String(m).padStart(2, '0'), mark = path.join(root, `.xong_${y}-${mm}`);
  if (fs.existsSync(mark)) continue;
  const zip = path.join(tmp, `${y}-${mm}.zip`), csv = path.join(tmp, `Exness_${sym}_${y}_${mm}.csv`);
  try {
    const url = `https://ticks.ex2archive.com/ticks/${sym}/${y}/${mm}/Exness_${sym}_${y}_${mm}.zip`;
    let code;
    try { code = execFileSync('curl', ['-sS', '-m', '900', '--retry', '3', '-o', zip, '-w', '%{http_code}', url]).toString(); }
    catch (e) { console.error(`loi_tai: ${sym} ${y}-${mm}: ${e.message}`); failed++; continue; }
    if (code === '404') { console.log(`${sym} ${y}-${mm}: kho không có`); fs.writeFileSync(mark, ''); missing++; continue; }
    if (code !== '200') { console.error(`loi_tai: ${sym} ${y}-${mm}: HTTP ${code}`); failed++; continue; }
    try { execFileSync('unzip', ['-o', '-q', zip, '-d', tmp]); }
    catch (e) { console.error(`loi_giai_nen: ${sym} ${y}-${mm}: ${e.message}`); failed++; continue; }
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
    fs.writeFileSync(mark, '');
    done++;
    console.log(`${sym} ${y}-${mm}: ${days.size} ngày${bad ? `, bỏ ${bad} dòng lỗi` : ''}`);
  } catch (e) { console.error(`loi_xu_ly: ${sym} ${y}-${mm}: ${e.message}`); failed++; }
  finally { fs.rmSync(csv, { force: true }); fs.rmSync(zip, { force: true }); }         // luôn dọn file tạm, kể cả khi lỗi
}
fs.rmSync(tmp, { recursive: true, force: true });
console.log(`xong ${sym}: ${done} tháng tải xong, ${missing} tháng kho không có, ${failed} tháng lỗi (chạy lại để tải tiếp)`);
if (failed) process.exit(2);
