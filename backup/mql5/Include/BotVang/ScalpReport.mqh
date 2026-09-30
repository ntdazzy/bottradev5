// Sổ quyết định và tổng kết từ deal thật của máy thử, không cộng lệnh ảo.
#ifndef BOTVANG_SCALPREPORT_MQH
#define BOTVANG_SCALPREPORT_MQH

struct ScalpResult
  {
   ulong             id;
   datetime          opened, closed;
   double            entry, inVolume, outVolume, money, stress;
   int               dir;
  };

class CScalpReport
  {
private:
   int               m_file, m_candles, m_bars, m_candleErrors;
   datetime          m_lastBar;
   string            m_folder;
public:
                     CScalpReport(void) : m_file(INVALID_HANDLE), m_candles(INVALID_HANDLE), m_bars(0), m_candleErrors(0), m_lastBar(0) {}
   void              Init(string folder, bool exportCandles = false)
     {
      m_folder = folder;
      m_file = FileOpen(folder + "quyet_dinh.csv", FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_SHARE_READ, 0, CP_UTF8);
      if(m_file == INVALID_HANDLE) Print("[ScalpReport] file_open_failed err=", GetLastError());
      else FileWriteString(m_file, "luc;su_kien;chi_tiet\r\n");
      if(exportCandles)
        {
         m_candles = FileOpen(folder + "nen_M1.csv", FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_SHARE_READ, 0, CP_UTF8);
         if(m_candles == INVALID_HANDLE) { m_candleErrors++; Print("[ScalpReport] candles_open_failed err=", GetLastError()); }
         else FileWriteString(m_candles, "time;open;high;low;close;tick_volume;spread_price;atr;rsi;activity;h1;h4;d1;known_at\r\n");
        }
     }
   void              Candle(const MqlRates &r, double atr, double rsi, double activity, int h1, int h4, int d1, datetime known)
     {
      if(m_candles == INVALID_HANDLE) return;
      if(r.time <= m_lastBar || r.time + 60 > known) { m_candleErrors++; return; }
      string row = StringFormat("%s;%s;%s;%s;%s;%I64d;%.6f;%.6f;%.6f;%.6f;%d;%d;%d;%s\r\n",
         TimeToString(r.time, TIME_DATE | TIME_SECONDS), DoubleToString(r.open, _Digits), DoubleToString(r.high, _Digits),
         DoubleToString(r.low, _Digits), DoubleToString(r.close, _Digits), r.tick_volume, r.spread * _Point, atr, rsi, activity,
         h1, h4, d1, TimeToString(known, TIME_DATE | TIME_SECONDS));
      if(FileWriteString(m_candles, row) == 0) { m_candleErrors++; Print("[ScalpReport] candle_write_failed err=", GetLastError()); }
      else { m_bars++; m_lastBar = r.time; }
     }
   void              Add(string event, string detail)
     {
      StringReplace(detail, ";", ","); StringReplace(detail, "\n", " ");
      if(m_file != INVALID_HANDLE)
        {
         FileWriteString(m_file, TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS) + ";" + event + ";" + detail + "\r\n");
         if(event != "bo") FileFlush(m_file); // giữ quyết định quan trọng nếu terminal bị ngắt đột ngột
        }
     }
   void              Close(void)
     {
      if(m_file != INVALID_HANDLE) { FileClose(m_file); m_file = INVALID_HANDLE; }
      if(m_candles != INVALID_HANDLE) { FileClose(m_candles); m_candles = INVALID_HANDLE; }
     }
   // Báo riêng tiền sàn và phép trừ thêm chi phí chịu đựng. Không coi phép trừ là giả lập lại đường giá.
   double            Finish(long magic, datetime from, double slip, double drawdown, int be, int trailing, int early,
                            int signals, int rejected, int sent, int cancelled, int errors, int checks, int days,
                            double startBalance, string settings)
     {
      if(!HistorySelect(from, TimeCurrent())) { Print("[ScalpReport] history_failed err=", GetLastError()); return 0.0; }
      if(m_candles != INVALID_HANDLE) FileFlush(m_candles);
      checks += m_candleErrors;
      ScalpResult a[];
      double sumDeals = 0.0;
      int h = FileOpen(m_folder + "deals.csv", FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON, 0, CP_UTF8);
      if(h == INVALID_HANDLE) { Print("[ScalpReport] deals_open_failed err=", GetLastError()); return 0.0; }
      FileWriteString(h, "deal;lenh;luc;loai;vao_ra;khoi_luong;gia;loi;hoa_hong;phi;qua_dem;ly_do;time_msc\r\n");
      for(int i = 0; i < HistoryDealsTotal(); i++)
        {
         ulong d = HistoryDealGetTicket(i);
         if(HistoryDealGetInteger(d, DEAL_MAGIC) != magic || HistoryDealGetString(d, DEAL_SYMBOL) != _Symbol) continue;
         long type = HistoryDealGetInteger(d, DEAL_TYPE), kind = HistoryDealGetInteger(d, DEAL_ENTRY);
         if(type != DEAL_TYPE_BUY && type != DEAL_TYPE_SELL) continue;
         ulong id = (ulong)HistoryDealGetInteger(d, DEAL_POSITION_ID);
         int k = ArraySize(a) - 1;
         while(k >= 0 && a[k].id != id) k--;
         if(k < 0) { k = ArraySize(a); ArrayResize(a, k + 1, 1024); ZeroMemory(a[k]); a[k].id = id; }
         double vol = HistoryDealGetDouble(d, DEAL_VOLUME), price = HistoryDealGetDouble(d, DEAL_PRICE);
         double profit = HistoryDealGetDouble(d, DEAL_PROFIT), commission = HistoryDealGetDouble(d, DEAL_COMMISSION);
         double fee = HistoryDealGetDouble(d, DEAL_FEE), swap = HistoryDealGetDouble(d, DEAL_SWAP);
         double money = profit + commission + fee + swap;
         datetime at = (datetime)HistoryDealGetInteger(d, DEAL_TIME);
         long reason = HistoryDealGetInteger(d, DEAL_REASON);
         a[k].money += money; sumDeals += money;
         double penalty = 0.0;
         if(kind == DEAL_ENTRY_IN)
           {
            a[k].dir = type == DEAL_TYPE_BUY ? 1 : -1;
            a[k].entry += price * vol; a[k].inVolume += vol;
            if(a[k].opened == 0 || at < a[k].opened) a[k].opened = at;
            ulong order = (ulong)HistoryDealGetInteger(d, DEAL_ORDER);
            long ot = HistoryOrderGetInteger(order, ORDER_TYPE);
            if(ot == ORDER_TYPE_BUY || ot == ORDER_TYPE_SELL) penalty = slip;
           }
         else
           {
            a[k].outVolume += vol; a[k].closed = at;
            if(reason != DEAL_REASON_TP) penalty = slip;
           }
         if(penalty > 0.0)
           {
            double cost;
            if(OrderCalcProfit(ORDER_TYPE_BUY, _Symbol, vol, price, price - penalty, cost)) a[k].stress += cost;
            else { checks++; Print("[ScalpReport] cost_failed err=", GetLastError()); }
           }
         FileWriteString(h, StringFormat("%I64u;%I64u;%s;%d;%d;%.2f;%s;%.2f;%.2f;%.2f;%.2f;%d;%I64d\r\n", d, id,
            TimeToString(at, TIME_DATE | TIME_SECONDS), (int)type, (int)kind, vol, DoubleToString(price, _Digits), profit, commission, fee, swap, (int)reason,
            HistoryDealGetInteger(d, DEAL_TIME_MSC)));
        }
      FileClose(h);
      h = FileOpen(m_folder + "lenh.csv", FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON, 0, CP_UTF8);
      if(h == INVALID_HANDLE) { Print("[ScalpReport] orders_open_failed err=", GetLastError()); return 0.0; }
      FileWriteString(h, "lenh;mo;dong;chieu;khoi_luong;gia_khop;phut;da_xong;tien;tru_them_truot\r\n");
      double sum = 0.0, stress = 0.0, win = 0.0, loss = 0.0, hold = 0.0, all = 0.0;
      int done = 0, nw = 0, nl = 0, ns = 0, unfinished = 0;
      for(int k = 0; k < ArraySize(a); k++)
        {
         bool closed = a[k].inVolume > 0.0 && MathAbs(a[k].inVolume - a[k].outVolume) < 1e-8;
         double minutes = closed ? (double)(a[k].closed - a[k].opened) / 60.0 : 0.0;
         all += a[k].money;
         if(closed)
           {
            done++; sum += a[k].money; stress += a[k].money + a[k].stress; hold += minutes;
            if(a[k].money > 0.0) { nw++; win += a[k].money; }
            if(a[k].money < 0.0) { nl++; loss += a[k].money; }
            if(a[k].money + a[k].stress > 0.0) ns++;
           }
         else unfinished++;
         FileWriteString(h, StringFormat("%I64u;%s;%s;%d;%.2f;%s;%.2f;%d;%.2f;%.2f\r\n", a[k].id,
            TimeToString(a[k].opened, TIME_DATE | TIME_SECONDS), TimeToString(a[k].closed, TIME_DATE | TIME_SECONDS), a[k].dir,
            a[k].inVolume, DoubleToString(a[k].inVolume > 0.0 ? a[k].entry / a[k].inVolume : 0.0, _Digits), minutes,
            (int)closed, a[k].money, a[k].money + a[k].stress));
        }
      FileClose(h);
      if(MathAbs(all - sumDeals) > 0.01) checks++;
      double balanceGap = AccountInfoDouble(ACCOUNT_BALANCE) - startBalance - sumDeals;
      if(MathAbs(balanceGap) > 0.02) checks++;
      string text = StringFormat("BotScalpPhanUng %s %s\r\nNgay co tick %d; tin hieu %d; bo %d; gui %d; huy lenh cho %d; loi gui %d\r\n"
         "Lenh da dong %d; chua xong %d; lenh/ngay %.2f; thang %.2f%%\r\nTien sau phi san %.2f; TB/lenh %.3f; thang TB %.3f; thua TB %.3f; giu TB %.2f phut\r\n"
         "Tru them truot %.2f gia/chang thi truong: tien %.2f; TB/lenh %.3f; thang %.2f%%\r\n"
         "Sut von lon nhat %.2f; doi ve gia khop %d; siet theo nen %d; dong som %d\r\nTu kiem tra loi %d; tong deal - tong so %.6f\r\n"
         "Day la do qua khu da tung duoc xem, KHONG phai demo gia moi. Tru them truot chi la phep thu chi phi, khong doi duong gia.\r\n",
         _Symbol, EnumToString(_Period), days, signals, rejected, sent, cancelled, errors, done, unfinished,
         days > 0 ? (double)done / days : 0.0, done > 0 ? 100.0 * nw / done : 0.0, sum, done > 0 ? sum / done : 0.0,
         nw > 0 ? win / nw : 0.0, nl > 0 ? loss / nl : 0.0, done > 0 ? hold / done : 0.0,
         slip, stress, done > 0 ? stress / done : 0.0, done > 0 ? 100.0 * ns / done : 0.0, drawdown, be, trailing, early, checks, sumDeals - all);
      text += StringFormat("So du san - von dau - tong deal %.6f; tu %s den %s\r\n%s\r\n", balanceGap,
                           TimeToString(from, TIME_DATE | TIME_SECONDS), TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS), settings);
      text += StringFormat("Nen M1 da xuat %d; loi nen %d; gio san (khong tu doi UTC); spread nen KHONG phai spread tai moi tick\r\n", m_bars, m_candleErrors);
      h = FileOpen(m_folder + "tong_ket.txt", FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON, 0, CP_UTF8);
      if(h != INVALID_HANDLE) { FileWriteString(h, text); FileClose(h); }
      else Print("[ScalpReport] summary_open_failed err=", GetLastError());
      Print("[ScalpReport] ", text);
      return sum;
     }
  };

#endif
