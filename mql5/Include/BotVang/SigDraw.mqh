// SigDraw.mqh — vẽ cản khung lớn và tín hiệu lên biểu đồ khi chạy máy thử có hình (để chủ bot kiểm cản đúng chỗ).
// Chỉ vẽ đối tượng biểu đồ; không gửi lệnh, không ảnh hưởng số đo.
#ifndef SIG_DRAW_MQH
#define SIG_DRAW_MQH

#include "SigLevels.mqh"

// Màu theo nhóm cản: khung càng lớn màu càng đậm.
color SigGroupColor(int g)
  {
   switch(g)
     {
      case SIG_G_M5TAM: return clrSilver;
      case 1: return clrLightSkyBlue;   // M15
      case 2: return clrDeepSkyBlue;    // M30
      case 3: return clrGold;           // H1
      case 4: return clrOrange;         // H4
      case 5: return clrOrangeRed;      // D1
      case 6: return clrMagenta;        // W1
      case SIG_G_PD: case SIG_G_PW: return clrMediumPurple;
     }
   return clrDimGray;                   // số tròn
  }

// Vẽ/cập nhật các cản thật trong bán kính quanh giá. Cản đã chết giữ nguyên hình tới lúc chết.
void SigDrawLevels(SigLevelBook &book, datetime now, double price, double radius)
  {
   for(int i=0;i<book.Count();i++)
     {
      SigLevel z;
      if(!book.Get(i,z) || z.fake || z.known_at>now) continue;
      if(z.type==SIG_LV_ROUND) continue;
      string name="sig_lv_"+IntegerToString(z.id);
      bool exists=(ObjectFind(0,name)>=0);
      if(!z.alive)
        {
         if(exists) ObjectSetInteger(0,name,OBJPROP_TIME,1,z.dead_at);
         continue;
        }
      if(z.bottom-radius>price || z.top+radius<price) continue;
      double top=z.top, bottom=z.bottom;
      if(top-bottom<0.05) { top+=0.05; bottom-=0.05; }
      if(!exists)
        {
         ObjectCreate(0,name,OBJ_RECTANGLE,0,z.origin,bottom,now,top);
         ObjectSetInteger(0,name,OBJPROP_COLOR,SigGroupColor(z.group));
         ObjectSetInteger(0,name,OBJPROP_FILL,false);
         ObjectSetInteger(0,name,OBJPROP_STYLE,z.flip>0 ? STYLE_DASH : STYLE_SOLID);
         ObjectSetInteger(0,name,OBJPROP_BACK,true);
         ObjectSetString(0,name,OBJPROP_TOOLTIP,SigGroupName(z.group)+" "+SigTypeName(z.type)+
                         (z.flip>0?" doi_vai":"")+(z.role>0?" ho_tro":(z.role<0?" khang_cu":""))+
                         " ["+DoubleToString(z.bottom,2)+" - "+DoubleToString(z.top,2)+"]");
        }
      else ObjectSetInteger(0,name,OBJPROP_TIME,1,now);
     }
  }

// Mũi tên tại điểm vào, đoạn ngắn tại dừng lỗ và đích cản khung lớn.
void SigDrawSignal(long id, datetime t, int dir, double entry, double sl, double tp, const string text)
  {
   string base="sig_in_"+IntegerToString(id);
   ObjectCreate(0,base,dir>0 ? OBJ_ARROW_BUY : OBJ_ARROW_SELL,0,t,entry);
   ObjectSetString(0,base,OBJPROP_TOOLTIP,text);
   ObjectCreate(0,base+"_sl",OBJ_TREND,0,t,sl,t+1800,sl);
   ObjectSetInteger(0,base+"_sl",OBJPROP_COLOR,clrRed);
   ObjectSetInteger(0,base+"_sl",OBJPROP_RAY_RIGHT,false);
   if(tp>0)
     {
      ObjectCreate(0,base+"_tp",OBJ_TREND,0,t,tp,t+1800,tp);
      ObjectSetInteger(0,base+"_tp",OBJPROP_COLOR,clrLime);
      ObjectSetInteger(0,base+"_tp",OBJPROP_RAY_RIGHT,false);
     }
  }

#endif // SIG_DRAW_MQH
