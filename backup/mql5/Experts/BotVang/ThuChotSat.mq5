// ThuChotSat: đo lệnh chờ có chốt lời/dừng lỗ rất sát. CHỈ ĐỂ ĐO trong Strategy Tester.
// Mỗi phút, khi không còn lệnh nào: đặt 1 MUA chờ (limit) tại Ask − bước và 1 BÁN chờ (limit) tại Bid + bước, mỗi lệnh có
// chốt lời/dừng lỗ tính từ giá đặt; lệnh chờ chưa khớp sau 60 giây thì gỡ. Đếm lệnh về chốt lời / dính dừng lỗ.
#property copyright "BotVang"
#property version   "1.00"
#property description "Đo lệnh chờ có chốt lời/dừng lỗ rất sát (SPEC §20). Chỉ để đo."

input string InpRunName = "chotsat";   // Tên lần chạy (thư mục kết quả)
input long   InpMagic = 20260929;      // Mã nhận diện lệnh (Magic)
input double InpLot = 0.01;            // Lot mỗi lệnh (lot nhỏ nhất)
input double InpStep = 0.06;           // Lệnh chờ cách giá (vàng 0,06; BTC 10)
input double InpTp = 0.06;             // Chốt lời cách giá đặt (vàng 0,06; BTC 10)
input double InpSl = 0.05;             // Dừng lỗ cách giá đặt (vàng 0,05; BTC 10)

datetime g_nextPlace = 0;
datetime g_placedAt = 0;
long     g_fills = 0, g_tp = 0, g_sl = 0, g_other = 0, g_rejects = 0;
long     g_tpInstant = 0, g_slInstant = 0;   // đóng ngay trong giây khớp
double   g_pnl = 0.0, g_pnlTp = 0.0, g_pnlSl = 0.0, g_spreadSum = 0.0;
string   g_lastError = "";
double   g_startEq = 0.0;
datetime g_openTime[];                        // giờ khớp theo mã lệnh (để đo "đóng ngay")
long     g_openId[];

double Norm(double p)
  {
   double tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   return NormalizeDouble(MathRound(p / tick) * tick, _Digits);
  }

bool Send(MqlTradeRequest &r)
  {
   MqlTradeResult res;
   ZeroMemory(res);
   if(OrderSend(r, res) && (res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_PLACED))
      return true;
   g_rejects++;
   g_lastError = "mã " + (string)res.retcode + " " + res.comment;
   return false;
  }

void PlaceLimit(ENUM_ORDER_TYPE type, double price, double tp, double sl)
  {
   MqlTradeRequest r;
   ZeroMemory(r);
   r.action = TRADE_ACTION_PENDING;
   r.symbol = _Symbol;
   r.magic = (ulong)InpMagic;
   r.type = type;
   r.volume = InpLot;
   r.price = Norm(price);
   r.tp = Norm(tp);
   r.sl = Norm(sl);
   r.type_time = ORDER_TIME_GTC;
   r.type_filling = ORDER_FILLING_RETURN;
   Send(r);
  }

int CountMine(int &orders)
  {
   int pos = 0;
   orders = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(PositionGetTicket(i) != 0 && PositionGetInteger(POSITION_MAGIC) == InpMagic && PositionGetString(POSITION_SYMBOL) == _Symbol)
         pos++;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong tk = OrderGetTicket(i);
      if(tk != 0 && OrderGetInteger(ORDER_MAGIC) == InpMagic && OrderGetString(ORDER_SYMBOL) == _Symbol)
         orders++;
     }
   return pos;
  }

void RemoveOrders(void)
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong tk = OrderGetTicket(i);
      if(tk == 0 || OrderGetInteger(ORDER_MAGIC) != InpMagic || OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      MqlTradeRequest r;
      ZeroMemory(r);
      r.action = TRADE_ACTION_REMOVE;
      r.order = tk;
      Send(r);
     }
  }

int OnInit()
  {
   if(InpStep <= 0.0 || InpTp <= 0.0 || InpSl <= 0.0)
      return INIT_PARAMETERS_INCORRECT;
   return INIT_SUCCEEDED;
  }

void OnTick()
  {
   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t))
      return;
   if(g_startEq == 0.0)
      g_startEq = AccountInfoDouble(ACCOUNT_EQUITY);
   int orders;
   int pos = CountMine(orders);
   if(pos == 0 && orders > 0 && t.time - g_placedAt >= 60)
      RemoveOrders();
   if(pos > 0 || orders > 0 || t.time < g_nextPlace)
      return;
   // MUA chờ dưới giá, BÁN chờ trên giá; chốt lời/dừng lỗ tính từ giá đặt
   double buy = t.ask - InpStep, sell = t.bid + InpStep;
   PlaceLimit(ORDER_TYPE_BUY_LIMIT, buy, buy + InpTp, buy - InpSl);
   PlaceLimit(ORDER_TYPE_SELL_LIMIT, sell, sell - InpTp, sell + InpSl);
   g_placedAt = t.time;
   g_nextPlace = t.time + 60;
  }

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD || !HistoryDealSelect(trans.deal))
      return;
   if(HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != InpMagic)
      return;
   long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   long id = HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
   datetime at = (datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME);
   if(entry == DEAL_ENTRY_IN)
     {
      MqlTick t;
      SymbolInfoTick(_Symbol, t);
      g_fills++;
      g_spreadSum += t.ask - t.bid;
      int n = ArraySize(g_openId);
      ArrayResize(g_openId, n + 1, 1024);
      ArrayResize(g_openTime, n + 1, 1024);
      g_openId[n] = id;
      g_openTime[n] = at;
      return;
     }
   if(entry != DEAL_ENTRY_OUT)
      return;
   double p = HistoryDealGetDouble(trans.deal, DEAL_PROFIT) + HistoryDealGetDouble(trans.deal, DEAL_SWAP) + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
   long reason = HistoryDealGetInteger(trans.deal, DEAL_REASON);
   bool instant = false;
   for(int i = ArraySize(g_openId) - 1; i >= 0 && i >= ArraySize(g_openId) - 10; i--)
      if(g_openId[i] == id)
         instant = at - g_openTime[i] <= 1;
   g_pnl += p;
   if(reason == DEAL_REASON_TP)
     {
      g_tp++;
      g_pnlTp += p;
      if(instant)
         g_tpInstant++;
     }
   else
      if(reason == DEAL_REASON_SL)
        {
         g_sl++;
         g_pnlSl += p;
         if(instant)
            g_slInstant++;
        }
      else
         g_other++;
  }

double OnTester()
  {
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   long closed = g_tp + g_sl + g_other;
   string lines[8];
   lines[0] = StringFormat("%s %s: bước %s, chốt lời %s, dừng lỗ %s, lot %.2f; vốn %.2f -> %.2f", InpRunName, _Symbol,
                           DoubleToString(InpStep, _Digits), DoubleToString(InpTp, _Digits), DoubleToString(InpSl, _Digits), InpLot, g_startEq, eq);
   lines[1] = StringFormat("Lệnh khớp: %I64d; đã đóng %I64d: về chốt lời %I64d (%.1f%%), dính dừng lỗ %I64d (%.1f%%), khác %I64d",
                           g_fills, closed, g_tp, closed > 0 ? 100.0 * g_tp / closed : 0.0, g_sl, closed > 0 ? 100.0 * g_sl / closed : 0.0, g_other);
   lines[2] = StringFormat("Đóng ngay trong 1 giây sau khi khớp: dừng lỗ %I64d, chốt lời %I64d", g_slInstant, g_tpInstant);
   lines[3] = StringFormat("Lời/lỗ: tổng %.2f; về chốt lời %.2f; dính dừng lỗ %.2f; trung bình mỗi lệnh %.3f", g_pnl, g_pnlTp, g_pnlSl,
                           closed > 0 ? g_pnl / closed : 0.0);
   lines[4] = StringFormat("Chênh lệch mua-bán trung bình lúc khớp: %.3f giá", g_fills > 0 ? g_spreadSum / g_fills : 0.0);
   lines[5] = StringFormat("Sàn từ chối yêu cầu: %I64d lần%s", g_rejects, g_lastError != "" ? " (lần cuối: " + g_lastError + ")" : "");
   int h = FileOpen("BotLuoi\\" + InpRunName + "_" + _Symbol + "_tong_ket.txt", FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON, 0, CP_UTF8);
   for(int i = 0; i < 6; i++)
     {
      Print("[ThuChotSat] ", lines[i]);
      if(h != INVALID_HANDLE)
         FileWriteString(h, lines[i] + "\r\n");
     }
   if(h != INVALID_HANDLE)
      FileClose(h);
   return eq - g_startEq;
  }
