// Ghép kế hoạch, khớp và dời dừng với deal thật; chuẩn bị đối chứng tick, không sửa luật EA.
import { readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';

const folder = process.argv[2];
if (!folder) throw Error('Dùng: node scripts/diagnose-scalp.mjs <thư mục kết quả>');
async function csv(name) {
  const lines = (await readFile(join(folder, name), 'utf8')).trim().split(/\r?\n/);
  const keys = lines.shift().replace(/^\uFEFF/, '').split(';');
  return lines.filter(Boolean).map(line => {
    const cells = line.split(';');
    if (cells.length !== keys.length) throw Error(`Sai số cột trong ${name}`);
    return Object.fromEntries(keys.map((key, i) => [key, cells[i]]));
  });
}
const [trades, deals, events] = await Promise.all([csv('lenh.csv'), csv('deals.csv'), csv('quyet_dinh.csv')]);
const index = new Map(trades.map(t => [`${t.mo}|${t.chieu}|${Number(t.gia_khop)}`, t]));
if (index.size !== trades.length) throw Error('Giờ/chiều/giá khớp bị trùng, không thể ghép chắc chắn');
const cases = new Map();
let plan = null, active = null;
for (const event of events) {
  const detail = event.chi_tiet;
  if (event.su_kien === 'ke_hoach') {
    const match = detail.match(/^(MUA|BAN) (cho hoi|thi truong), vao ([\d.]+), dung ([\d.]+), chot ([\d.]+)/);
    if (!match) throw Error('Không đọc được kế hoạch');
    plan = { dir: match[1] === 'MUA' ? 1 : -1, market: match[2] === 'thi truong', entry: Number(match[3]), sl: Number(match[4]), tp: Number(match[5]),
      early: Number(detail.match(/som ([01])/)?.[1] ?? 0), atr: Number(detail.match(/ATR ([\d.]+)/)?.[1]),
      reaction: detail.match(/phanung (R\d)/)?.[1] ?? 'unknown', zone: detail.match(/loai (\w+)/)?.[1] ?? 'unknown', at: event.luc };
  }
  if (event.su_kien === 'huy') plan = null;
  if (event.su_kien === 'khop') {
    const match = detail.match(/^(MUA|BAN) gia ([\d.]+), dung ([\d.]+), chot ([\d.]+)/);
    if (!match || !plan) throw Error('Khớp thiếu kế hoạch');
    const dir = match[1] === 'MUA' ? 1 : -1, fill = Number(match[2]);
    // Sự kiện khớp có thể tới sau deal (đã gặp trễ 1 giây). Chỉ ghép nếu duy nhất trong cửa sổ kế hoạch.
    const matching = trades.filter(t => !cases.has(t.lenh) && Number(t.chieu) === dir && Number(t.gia_khop) === fill
      && t.mo >= plan.at && t.mo <= event.luc);
    if (matching.length !== 1 || plan.dir !== dir) throw Error(`Không ghép duy nhất lệnh: ${event.luc}, dir=${dir}, fill=${fill}, candidates=${matching.length}`);
    const trade = matching[0];
    active = { ...plan, id: trade.lenh, opened: trade.mo, closed: trade.dong, fill, sl: Number(match[3]), tp: Number(match[4]),
      finalSl: Number(match[3]), money: Number(trade.tien), minutes: Number(trade.phut), volume: Number(trade.khoi_luong), moves: 0 };
    cases.set(active.id, active); plan = null;
  }
  if (event.su_kien === 'doi_dung') {
    const match = detail.match(/Dừng mới ([\d.]+), giữ chốt ([\d.]+)/);
    if (!active || !match || Math.abs(Number(match[2]) - active.tp) > 0.002) throw Error('Dời dừng không khớp kế hoạch');
    active.finalSl = Number(match[1]); active.moves++;
  }
  if (event.su_kien === 'dong' && active) active.closeNote = detail;
}
if (cases.size !== trades.length) throw Error('Có lệnh chưa ghép được');
for (const c of cases.values()) {
  const rows = deals.filter(d => d.lenh === c.id);
  const entries = rows.filter(d => Number(d.vao_ra) === 0), exits = rows.filter(d => Number(d.vao_ra) === 1);
  if (entries.length !== 1 || exits.length !== 1) throw Error('Chưa hỗ trợ khớp từng phần trong công cụ điều tra');
  c.exitReason = Number(exits[0].ly_do); c.openMsc = Number(entries[0].time_msc || 0); c.closeMsc = Number(exits[0].time_msc || 0);
  c.fees = rows.reduce((sum, d) => sum + Number(d.hoa_hong) + Number(d.phi) + Number(d.qua_dem), 0);
  c.risk = c.dir * (c.fill - c.sl); c.reward = c.dir * (c.tp - c.fill);
  c.adverseFill = c.dir * (c.fill - c.entry);
  c.exitGroup = c.exitReason === 5 ? 'chot_muc_tieu' : c.exitReason !== 4 ? 'dong_chu_dong'
    : c.dir * (c.finalSl - c.fill) >= -0.002 ? 'dung_sau_bao_ve_gia_vao'
    : c.moves > 0 ? 'dung_da_siet_nhung_chua_hoa_von' : 'dung_ban_dau';
}
const all = [...cases.values()];
function group(field) {
  return [...new Set(all.map(c => String(c[field])))].map(key => {
    const rows = all.filter(c => String(c[field]) === key);
    return { key, n: rows.length, wins: rows.filter(c => c.money > 0).length, losses: rows.filter(c => c.money < 0).length,
      net: rows.reduce((sum, c) => sum + c.money, 0), meanRisk: rows.reduce((sum, c) => sum + c.risk, 0) / rows.length,
      meanHoldMinutes: rows.reduce((sum, c) => sum + c.minutes, 0) / rows.length };
  });
}
const output = { trades: all.length, net: all.reduce((sum, c) => sum + c.money, 0), fees: all.reduce((sum, c) => sum + c.fees, 0),
  early: group('early'), market: group('market'), direction: group('dir'), exits: group('exitGroup'), reaction: group('reaction'), zone: group('zone'), cases: all };
await writeFile(join(folder, 'diagnose_summary.json'), JSON.stringify(output, null, 2) + '\n', { flag: 'wx' });
if (all.every(c => c.openMsc > 0 && c.closeMsc > 0)) {
  const head = 'id;open_msc;close_msc;dir;volume;fill;sl;tp;money;final_sl;exit_reason;early;market;atr';
  const lines = all.map(c => [c.id, c.openMsc, c.closeMsc, c.dir, c.volume, c.fill, c.sl, c.tp, c.money, c.finalSl, c.exitReason, c.early, Number(c.market), c.atr].join(';'));
  await writeFile(join(folder, 'diagnose_inputs.csv'), head + '\n' + lines.join('\n') + '\n', { flag: 'wx' });
} else console.log('Chưa có mili giây khớp: không tạo đối chứng tick từ giờ bị làm tròn.');
const { cases: omitted, ...summary } = output;
console.log(JSON.stringify(summary, null, 2));
