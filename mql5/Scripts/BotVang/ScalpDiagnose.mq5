// Đối chứng đường giá từng lệnh bằng tick broker. Chỉ đọc; KHÔNG gửi lệnh hay chỉnh EA.
#property script_show_inputs
input string InpRun = "scalp_v3_audit_XAUUSDm_M1";
input bool InpSelfTest = false;
input bool InpCloseTerminal = false;

struct Outcome { int reason; double price; }; // -2 không vào, -1 thiếu giá, 0 hết giờ, 1 dừng, 2 chốt

bool QuoteOk(const MqlTick &q) { return q.bid > 0.0 && q.ask >= q.bid; }
double ExitPrice(const MqlTick &q, int dir) { return dir > 0 ? q.bid : q.ask; }
Outcome Simulate(const MqlTick &ticks[], long start, long end, int dir, double sl, double tp)
  {
   Outcome result; result.reason = -1; result.price = 0.0;
   for(int i = 0; i < ArraySize(ticks); i++)
     {
      if(ticks[i].time_msc < start || !QuoteOk(ticks[i])) continue;
      double price = ExitPrice(ticks[i], dir);
      if(ticks[i].time_msc >= end)
        { result.reason = 0; result.price = price; return result; }
      if(dir * (price - sl) <= 0.0)
        { result.reason = 1; result.price = price; return result; }
      if(dir * (price - tp) >= 0.0)
        { result.reason = 2; result.price = price; return result; }
     }
   return result;
  }
bool Profit(int dir, double volume, double entry, const Outcome &result, double &money)
  {
   money = 0.0;
   if(result.reason < 0) return false;
   if(OrderCalcProfit(dir > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, "XAUUSDm", volume, entry, result.price, money))
     {
      double expected = dir * (result.price - entry) * volume * SymbolInfoDouble("XAUUSDm", SYMBOL_TRADE_CONTRACT_SIZE);
      if(MathAbs(expected - money) <= 0.011) return true;
      Print("[ScalpDiagnose] profit_mismatch expected=", expected, " actual=", money); return false;
     }
   Print("[ScalpDiagnose] profit_failed err=", GetLastError()); return false;
  }
bool SelfTest()
  {
   MqlTick q[]; ArrayResize(q, 3);
   for(int i = 0; i < 3; i++) { ZeroMemory(q[i]); q[i].time_msc = 1000 + i * 1000; q[i].bid = 100; q[i].ask = 100.3; }
   q[1].bid = 97; q[1].ask = 97.3; q[2].bid = 106; q[2].ask = 106.3;
   Outcome a = Simulate(q, 1000, 4000, 1, 98, 105);
   Outcome b = Simulate(q, 3000, 4000, 1, 98, 105);
   Outcome c = Simulate(q, 1000, 4000, -1, 103, 98);
   bool ok = a.reason == 1 && a.price == 97 && b.reason == 2 && b.price == 106 && c.reason == 2 && c.price == 97.3;
   Outcome time = Simulate(q, 1000, 2000, 1, 90, 120);
   ok = ok && time.reason == 0 && time.price == 97;
   Print("[ScalpDiagnose] self_test ", ok ? "PASS" : "FAIL"); return ok;
  }
void OnStart()
  {
   if(InpSelfTest) { bool ok = SelfTest(); if(InpCloseTerminal) TerminalClose(ok ? 0 : 1); return; }
   if(StringFind(InpRun, "..") >= 0 || StringFind(InpRun, "\\") >= 0 || StringFind(InpRun, "/") >= 0)
     { Print("[ScalpDiagnose] invalid_run"); if(InpCloseTerminal) TerminalClose(1); return; }
   // Script được MT5 chạy trước khi hoàn tất đăng nhập/tải thông số. Không nhận kết quả tiền 0 giả là hợp lệ.
   double probe = 0.0;
   bool probeOk = OrderCalcProfit(ORDER_TYPE_BUY, "XAUUSDm", 0.01, 4000, 4001, probe);
   Print("[ScalpDiagnose] before_ready connected=", TerminalInfoInteger(TERMINAL_CONNECTED), " probe_ok=", probeOk, " probe=", probe,
         " contract=", SymbolInfoDouble("XAUUSDm", SYMBOL_TRADE_CONTRACT_SIZE));
   bool ready = false;
   for(int attempt = 0; attempt < 200 && !IsStopped(); attempt++)
     {
      double contract = SymbolInfoDouble("XAUUSDm", SYMBOL_TRADE_CONTRACT_SIZE);
      if(TerminalInfoInteger(TERMINAL_CONNECTED) && AccountInfoString(ACCOUNT_CURRENCY) == "USD"
         && SymbolInfoString("XAUUSDm", SYMBOL_CURRENCY_PROFIT) == "USD" && contract > 0
         && OrderCalcProfit(ORDER_TYPE_BUY, "XAUUSDm", 0.01, 4000, 4001, probe) && MathAbs(probe - 0.01 * contract) < 0.000001)
        { ready = true; break; }
      Sleep(100);
     }
   if(!ready) { Print("[ScalpDiagnose] not_ready_or_unsupported_currency"); if(InpCloseTerminal) TerminalClose(1); return; }
   Print("[ScalpDiagnose] money_ready probe=", probe);
   string folder = "BotScalpPhanUng\\" + InpRun + "\\";
   if(FileIsExist(folder + "diagnose_ticks_final.csv", FILE_COMMON))
     { Print("[ScalpDiagnose] output_exists: không ghi đè"); if(InpCloseTerminal) TerminalClose(1); return; }
   int reader = FileOpen(folder + "diagnose_inputs.csv", FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON, 0, CP_UTF8);
   if(reader == INVALID_HANDLE)
     { Print("[ScalpDiagnose] input_failed err=", GetLastError()); if(InpCloseTerminal) TerminalClose(1); return; }
   string header = FileReadString(reader);
   if(header != "id;open_msc;close_msc;dir;volume;fill;sl;tp;money;final_sl;exit_reason;early;market;atr")
     { FileClose(reader); Print("[ScalpDiagnose] invalid_header"); if(InpCloseTerminal) TerminalClose(1); return; }
   int output = FileOpen(folder + "diagnose_ticks_final.csv", FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON, 0, CP_UTF8);
   if(output == INVALID_HANDLE)
     { FileClose(reader); Print("[ScalpDiagnose] output_failed err=", GetLastError()); if(InpCloseTerminal) TerminalClose(1); return; }
   FileWriteString(output, "id;status;ticks;pre_ticks;first_lag_ms;max_gap_ms;mfe_before;mae_before;mfe_10m;mae_10m;target_after_exit;fixed_reason;fixed_money;wide_reason;wide_money;wide_same_risk_money;reverse_reason;reverse_money;delay_reason;delay_money\r\n");
   int checked = 0, missing = 0, invalid = 0;
   while(!FileIsEnding(reader))
     {
      string line = FileReadString(reader); if(line == "") continue;
      string f[];
      if(StringSplit(line, ';', f) != 14) { invalid++; continue; }
      long opened = StringToInteger(f[1]), closed = StringToInteger(f[2]);
      long end = opened / 1000 * 1000 + 600000; // EA dùng POSITION_TIME (giây) để hết giờ, không dùng TIME_MSC.
      int dir = (int)StringToInteger(f[3]);
      double volume = StringToDouble(f[4]), entry = StringToDouble(f[5]), sl = StringToDouble(f[6]), tp = StringToDouble(f[7]);
      double risk = dir * (entry - sl), reward = dir * (tp - entry);
      if(opened <= 0 || closed < opened || risk <= 0 || reward <= 0 || volume <= 0 || (dir != 1 && dir != -1))
        { invalid++; continue; }
      MqlTick ticks[];
      ResetLastError();
      int count = CopyTicksRange("XAUUSDm", ticks, COPY_TICKS_ALL, (ulong)opened, (ulong)(end + 5000));
      int first = -1, pre = 0; long last = opened, maxGap = 0;
      double mfe = 0, mae = 0, mfeAll = 0, maeAll = 0;
      bool recovered = false;
      for(int i = 0; i < count; i++)
        {
         if(!QuoteOk(ticks[i])) continue;
         if(first < 0) first = i;
         maxGap = MathMax(maxGap, ticks[i].time_msc - last); last = ticks[i].time_msc;
         if(ticks[i].time_msc > end) continue;
         double move = dir * (ExitPrice(ticks[i], dir) - entry);
         mfeAll = MathMax(mfeAll, move); maeAll = MathMax(maeAll, -move);
         if(ticks[i].time_msc <= closed) { pre++; mfe = MathMax(mfe, move); mae = MathMax(mae, -move); }
         if(ticks[i].time_msc > closed && move >= reward) recovered = true;
        }
      long lag = first >= 0 ? ticks[first].time_msc - opened : -1;
      if(first < 0 || lag > 1000 || maxGap > 60000 || last < end)
        {
         missing++; FileWriteString(output, StringFormat("%s;missing_quotes;%d;%d;%I64d;%I64d;;;;;;;;;;;;;;\r\n", f[0], count, pre, lag, maxGap));
         Print("[ScalpDiagnose] missing_quotes id=", f[0], " count=", count, " err=", GetLastError()); continue;
        }
      Outcome fixed = Simulate(ticks, opened, end, dir, sl, tp);
      Outcome wide = Simulate(ticks, opened, end, dir, entry - dir * 1.5 * risk, tp);
      double reverseEntry = dir > 0 ? ticks[first].bid : ticks[first].ask;
      Outcome reverse = Simulate(ticks, opened, end, -dir, reverseEntry + dir * risk, reverseEntry - dir * reward);
      Outcome delay; delay.reason = -2; delay.price = 0;
      double delayEntry = 0;
      for(int i = first; i < count; i++)
        {
         if(!QuoteOk(ticks[i])) continue;
         double price = ExitPrice(ticks[i], dir);
         if(dir * (price - sl) <= 0 || dir * (price - tp) >= 0) break; // kế hoạch đã hỏng/chạy xong trước khi chờ đủ
         if(ticks[i].time_msc >= opened + 60000)
           {
            delayEntry = dir > 0 ? ticks[i].ask : ticks[i].bid;
            double newRisk = dir * (delayEntry - sl), newReward = dir * (tp - delayEntry);
            if(newRisk > 0 && newReward > 0 && (newReward - 0.5) / (newRisk + 1.0) >= 1.2
               && newRisk <= 3 * StringToDouble(f[13])) delay = Simulate(ticks, ticks[i].time_msc, end, dir, sl, tp);
            break;
           }
        }
      double fixedMoney, wideMoney, reverseMoney, delayMoney = 0;
      bool ok = Profit(dir, volume, entry, fixed, fixedMoney) && Profit(dir, volume, entry, wide, wideMoney)
                && Profit(-dir, volume, reverseEntry, reverse, reverseMoney);
      if(delay.reason >= 0 && !Profit(dir, volume, delayEntry, delay, delayMoney)) ok = false;
      if(!ok) { invalid++; continue; }
      FileWriteString(output, StringFormat("%s;ok;%d;%d;%I64d;%I64d;%.6f;%.6f;%.6f;%.6f;%d;%d;%.6f;%d;%.6f;%.6f;%d;%.6f;%d;%.6f\r\n",
         f[0], count, pre, lag, maxGap, mfe, mae, mfeAll, maeAll, (int)recovered,
         fixed.reason, fixedMoney, wide.reason, wideMoney, wideMoney / 1.5, reverse.reason, reverseMoney, delay.reason, delayMoney));
      checked++;
     }
   FileClose(reader); FileClose(output);
   PrintFormat("[ScalpDiagnose] checked=%d missing=%d invalid=%d; counterfactual ONLY, spread included, no extra slippage/fees; horizon=10min, wider=1.5x, delay=60s",
               checked, missing, invalid);
   if(InpCloseTerminal) TerminalClose(invalid > 0 ? 1 : 0);
  }
