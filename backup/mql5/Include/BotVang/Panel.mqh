// Bảng điều khiển trên biểu đồ: trạng thái + lý do, hướng lớn, biến động, chênh lệch, giờ chạy, tin sắp tới,
// cản/hỗ trợ gần nhất, lệnh đang chạy, lời/lỗ ngày/tuần/tổng, giới hạn ngày đã dùng, trượt giá; các nút; vẽ vùng.
#ifndef BOTVANG_PANEL_MQH
#define BOTVANG_PANEL_MQH

#include "Engine.mqh"

#define PANEL_LINES 16

class CPanel
  {
private:
   string            m_p;
   ulong             m_closeArmedMsc;
   int               m_zoneObjs;

   void              Label(int i, const string text, color c)
     {
      string n = m_p + "L" + (string)i;
      if(ObjectFind(0, n) < 0)
        {
         ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, n, OBJPROP_XDISTANCE, 12);
         ObjectSetInteger(0, n, OBJPROP_YDISTANCE, 26 + i * 17);
         ObjectSetString(0, n, OBJPROP_FONT, "Segoe UI");
         ObjectSetInteger(0, n, OBJPROP_FONTSIZE, 9);
         ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
        }
      ObjectSetString(0, n, OBJPROP_TEXT, text);
      ObjectSetInteger(0, n, OBJPROP_COLOR, c);
     }

   void              Button(const string id, int col, int row, const string text, color bg, bool show = true)
     {
      string n = m_p + "B_" + id;
      if(!show)
        {
         ObjectDelete(0, n);
         return;
        }
      if(ObjectFind(0, n) < 0)
        {
         ObjectCreate(0, n, OBJ_BUTTON, 0, 0, 0);
         ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, n, OBJPROP_XSIZE, 118);
         ObjectSetInteger(0, n, OBJPROP_YSIZE, 22);
         ObjectSetString(0, n, OBJPROP_FONT, "Segoe UI");
         ObjectSetInteger(0, n, OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, n, OBJPROP_COLOR, clrWhite);
        }
      ObjectSetInteger(0, n, OBJPROP_XDISTANCE, 12 + col * 122);
      ObjectSetInteger(0, n, OBJPROP_YDISTANCE, 30 + PANEL_LINES * 17 + row * 26);
      ObjectSetString(0, n, OBJPROP_TEXT, text);
      ObjectSetInteger(0, n, OBJPROP_BGCOLOR, bg);
      ObjectSetInteger(0, n, OBJPROP_STATE, false);
     }

   static string     Dir(int d) { return d > 0 ? "TĂNG" : (d < 0 ? "GIẢM" : "KHÔNG RÕ"); }
   static string     Money(double v) { return (v >= 0 ? "+" : "") + DoubleToString(v, 2); }
   static string     Pct(double v, double base) { return base > 0.0 ? DoubleToString(100.0 * v / base, 1) + "%" : "-"; }

   string            StateName(ENUM_BOT_STATE s)
     {
      switch(s)
        {
         case ST_WAIT:     return "CHỜ";
         case ST_RUN:      return "ĐANG CHẠY";
         case ST_AT_ZONE:  return "TẠI CẢN";
         case ST_PAUSE:    return "NGHỈ";
         case ST_CLOSING:  return "ĐANG ĐÓNG";
         case ST_RECOVERY: return "KHÔI PHỤC";
         case ST_STOPPED:  return "DỪNG HẲN";
        }
      return "?";
     }

   // Vùng gần nhất phía trên (kháng cự) hoặc phía dưới (hỗ trợ); vùng chỉ còn tham khảo cũng hiện, có đánh dấu
   string            NearestText(CZones &z, bool res, double price)
     {
      int best = -1;
      double bd = DBL_MAX;
      for(int i = 0; i < z.count; i++)
        {
         if(z.zones[i].dead || z.zones[i].isRes != res)
            continue;
         double d = res ? z.zones[i].lo - price : price - z.zones[i].hi;
         if(price >= z.zones[i].lo && price <= z.zones[i].hi)
            d = 0.0;
         if(d >= 0.0 && d < bd)
           {
            bd = d;
            best = i;
           }
        }
      if(best < 0)
         return "không có";
      Zone q = z.zones[best];
      string tf = q.tf == PERIOD_M15 ? "M15" : (q.tf == PERIOD_H1 ? "H1" : (q.tf == PERIOD_H4 ? "H4" : "Ngày"));
      return tf + " " + CZones::KindName(q) + ", điểm " + (string)q.score + ", đã chạm " + (string)q.touches
             + (ZoneIsBarrier(q) ? "" : " (chỉ tham khảo)") + ", cách " + DoubleToString(bd, 2);
     }

public:
   void              Init(void)
     {
      m_p = "BVP_";
      m_closeArmedMsc = 0;
      m_zoneObjs = 0;
      string bg = m_p + "BG";
      ObjectCreate(0, bg, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, bg, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, bg, OBJPROP_XDISTANCE, 4);
      ObjectSetInteger(0, bg, OBJPROP_YDISTANCE, 20);
      ObjectSetInteger(0, bg, OBJPROP_XSIZE, 500);
      ObjectSetInteger(0, bg, OBJPROP_YSIZE, 20 + PANEL_LINES * 17 + 3 * 26);
      ObjectSetInteger(0, bg, OBJPROP_BGCOLOR, C'20,24,32');
      ObjectSetInteger(0, bg, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, bg, OBJPROP_SELECTABLE, false);
     }

   void              Destroy(void)
     {
      ObjectsDeleteAll(0, m_p);
      ObjectsDeleteAll(0, "BVZ_");
     }

   void              Update(CEngine &e, CJournal &log, datetime now)
     {
      MqlTick t;
      SymbolInfoTick(_Symbol, t);
      color stc = e.state == ST_RUN || e.state == ST_AT_ZONE ? clrLime : (e.state == ST_WAIT ? clrSilver
                  : (e.state == ST_STOPPED || e.state == ST_RECOVERY ? clrTomato : clrGold));
      Label(0, "BotVang  |  " + StateName(e.state) + ": " + e.reason, stc);
      Label(1, "Hướng lớn: H4 " + Dir(e.biasH4) + ", H1 " + Dir(e.biasH1) + " → " + Dir(e.bias), clrWhite);
      MqlDateTime vn;
      TimeToStruct(now + e.mc.vnOffset * 3600, vn);
      Label(2, "Biến động M5: " + DoubleToString(e.atrM5, 2) + "  |  Chênh lệch: " + DoubleToString(t.ask - t.bid, 2)
            + "  |  Giờ VN " + StringFormat("%02d:%02d", vn.hour, vn.min), clrWhite);
      datetime nx = e.news.Next(now);
      string newsText = !e.mc.newsFilter ? "lọc tin TẮT" : (!e.news.available ? "KHÔNG CÓ DỮ LIỆU TIN" :
                        (nx > 0 ? TimeToString(nx + e.mc.vnOffset * 3600, TIME_DATE | TIME_MINUTES) + " VN" : "không có trong 2 ngày"));
      Label(3, "Giờ chạy: " + StringFormat("%02d:%02d–%02d:%02d", e.mc.startMin / 60, e.mc.startMin % 60, e.mc.endMin / 60, e.mc.endMin % 60)
            + (e.timeOn ? " (BẬT)" : " (TẮT)") + "  |  Tin mạnh sắp tới: " + newsText, e.news.available || !e.mc.newsFilter ? clrWhite : clrTomato);
      Label(4, "Kháng cự gần nhất: " + NearestText(e.zones, true, t.bid), clrSalmon);
      Label(5, "Hỗ trợ gần nhất: " + NearestText(e.zones, false, t.bid), clrPaleGreen);
      if(e.hasPos)
         Label(6, "Lệnh: " + (e.posDir > 0 ? "MUA " : "BÁN ") + DoubleToString(e.posVol, 2) + " giá " + DoubleToString(e.posOpen, _Digits)
               + " | dừng lỗ " + DoubleToString(e.posSl, _Digits) + " | B " + DoubleToString(e.posB, 2) + " | lời/lỗ " + Money(e.posProfit), clrWhite);
      else
         Label(6, "Lệnh: không có" + (e.hasFlip ? " (còn lệnh chờ đảo)" : ""), clrSilver);
      Label(7, "Lời/lỗ ngày " + Money(e.money.dayPnl) + " (" + Pct(e.money.dayPnl, e.money.dayEq) + ")  |  tuần " + Money(e.money.weekPnl)
            + " (" + Pct(e.money.weekPnl, e.money.weekEq) + ")  |  từ đầu " + Money(e.money.totalPnl) + " (" + Pct(e.money.totalPnl, e.money.capital) + ")",
            e.money.dayPnl >= 0 ? clrWhite : clrSalmon);
      double lim = e.money.DayLimit(e.s);
      Label(8, "Hôm nay: thắng " + (string)e.money.winsToday + ", thua " + (string)e.money.lossesToday + "  |  Giới hạn lỗ ngày đã dùng: "
            + (lim > 0.0 ? DoubleToString(100.0 * e.money.DayUsed() / lim, 0) + "%" : "-") + " (" + DoubleToString(e.money.DayUsed(), 2) + "/" + DoubleToString(lim, 2) + ")",
            clrWhite);
      Label(9, "Trượt giá hôm nay: " + (e.slipCount > 0 ? "TB " + DoubleToString(e.slipSum / e.slipCount, 3) + ", xấu nhất " + DoubleToString(e.slipWorst, 3)
            + " (" + (string)e.slipCount + " lần)" : "chưa có"), clrWhite);
      Label(10, "Đảo chiều: " + (e.flipMode == FLIP_OFF ? "TẮT (chưa được Lab chứng minh)" : "CÓ ĐIỀU KIỆN") + "  |  Lot " + DoubleToString(e.lotSize, 2)
            + "  |  Thua liên tiếp: " + (string)e.consLosses, clrWhite);
      Label(11, e.lastSkip != "" ? "Lần bỏ tín hiệu gần nhất: " + e.lastSkip : "", clrGold);
      for(int i = 0; i < 4; i++)
         Label(12 + i, log.Recent(i), clrDarkGray);
      // Nút
      Button("on", 0, 0, e.botOn ? "Bot: BẬT" : "Bot: TẮT", e.botOn ? clrSeaGreen : clrDimGray);
      Button("buy", 1, 0, e.buyOn ? "Cho MUA: có" : "Cho MUA: không", e.buyOn ? clrSeaGreen : clrDimGray);
      Button("sell", 2, 0, e.sellOn ? "Cho BÁN: có" : "Cho BÁN: không", e.sellOn ? clrSeaGreen : clrDimGray);
      Button("time", 3, 0, e.timeOn ? "Lọc giờ: bật" : "Lọc giờ: tắt", e.timeOn ? clrSeaGreen : clrDimGray);
      Button("flip", 0, 1, e.flipMode == FLIP_OFF ? "Đảo: TẮT" : "Đảo: có điều kiện", e.flipMode == FLIP_OFF ? clrDimGray : clrDarkOrange);
      Button("lot", 1, 1, "Lot " + DoubleToString(e.lotSize, 2), clrSteelBlue);
      bool armed = GetTickCount64() - m_closeArmedMsc < 5000;
      Button("close", 2, 1, armed ? "Bấm lần nữa để đóng" : "Đóng hết", armed ? clrCrimson : clrFireBrick);
      Button("restart", 3, 1, "Cho chạy lại", clrDarkOrange, e.hardStop);
      bool noSl = e.RecoveryNoSl();
      Button("rmanage", 0, 2, "Bot quản lý, B " + DoubleToString(e.recoveryB, 2), clrSteelBlue, e.recovery && !noSl);
      Button("rclose", 1, 2, "Đóng lệnh này", clrFireBrick, e.recovery);
      Button("rprotect", 2, 2, "Đặt dừng lỗ bảo vệ", clrCrimson, noSl);
      ChartRedraw();
     }

   // Xử lý bấm nút; trả về true nếu là nút của bảng
   bool              OnClick(const string name, CEngine &e)
     {
      if(StringFind(name, m_p + "B_") != 0)
         return false;
      string id = StringSubstr(name, StringLen(m_p) + 2);
      if(id == "on")
         e.SetBotOn(!e.botOn);
      else
         if(id == "buy")
            e.SetBuy(!e.buyOn);
         else
            if(id == "sell")
               e.SetSell(!e.sellOn);
            else
               if(id == "time")
                  e.SetTime(!e.timeOn);
               else
                  if(id == "flip")
                     e.SetFlip(e.flipMode == FLIP_OFF ? FLIP_CONDITIONAL : FLIP_OFF);
                  else
                     if(id == "lot")
                       {
                        double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);   // lot nhỏ nhất ↔ gấp đôi
                        e.SetLot(e.lotSize < 1.5 * vmin ? 2 * vmin : vmin);
                       }
                     else
                        if(id == "close")
                          {
                           if(GetTickCount64() - m_closeArmedMsc < 5000)
                             {
                              m_closeArmedMsc = 0;
                              e.CloseAll();
                             }
                           else
                              m_closeArmedMsc = GetTickCount64();
                          }
                        else
                           if(id == "restart")
                              e.Restart();
                           else
                              if(id == "rmanage")
                                 e.RecoveryManage();
                              else
                                 if(id == "rclose")
                                    e.RecoveryClose();
                                 else
                                    if(id == "rprotect")
                                       e.RecoveryProtect();
      ObjectSetInteger(0, name, OBJPROP_STATE, false);
      return true;
     }

   // Vẽ vùng thật: đỏ kháng cự, xanh hỗ trợ, đậm hơn khi điểm cao; xám khi chỉ còn tham khảo
   void              DrawZones(CZones &z, int strongScore, datetime now)
     {
      ObjectsDeleteAll(0, "BVZ_");
      for(int i = 0; i < z.count; i++)
        {
         Zone q = z.zones[i];
         if(q.dead)
            continue;
         string n = "BVZ_" + (string)q.id;
         color c = !ZoneIsBarrier(q) ? C'70,70,70' : (q.isRes ? (q.score >= strongScore ? C'170,40,40' : C'90,35,35')
                   : (q.score >= strongScore ? C'30,140,60' : C'30,75,40'));
         double hi = MathMax(q.hi, q.lo + _Point);
         ObjectCreate(0, n, OBJ_RECTANGLE, 0, q.created, hi, now + 3600, q.lo);
         ObjectSetInteger(0, n, OBJPROP_COLOR, c);
         ObjectSetInteger(0, n, OBJPROP_FILL, true);
         ObjectSetInteger(0, n, OBJPROP_BACK, true);
         ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
         ObjectSetString(0, n, OBJPROP_TOOLTIP, CZones::KindName(q) + " điểm " + (string)q.score + ", đã chạm " + (string)q.touches);
        }
     }
  };

#endif
