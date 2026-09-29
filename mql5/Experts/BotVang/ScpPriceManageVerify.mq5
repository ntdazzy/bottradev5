// Chỉ máy thử: kiểm trọn chuỗi SELL 0,02 -> đi thuận 3 giá -> chốt 0,01 -> dừng giá vào -> khớp dừng.
// Dữ liệu ca: XAUUSDm 02/09/2026. Đây là ca quản lý vị thế dựng, không phải kiểm lợi thế điểm vào.
#property strict
#include <BotVang\ScpManage.mqh>

ScpState g_test_state;
ScpExec g_test_exec;
ScpManage g_test_manage;
int g_pass=0,g_fail=0;
bool g_started=false,g_scaled=false,g_finished=false;
datetime g_start_time=0;
ulong g_position_id=0;
double g_original_entry=0,g_original_tp=0;

void CheckPrice(bool ok,string name)
  {
   if(ok) g_pass++; else g_fail++;
   Print("[SCP_PRICE_TEST] ",ok?"PASS ":"FAIL ",name);
  }

int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER)) return INIT_FAILED;
   g_test_state.Init(_Symbol,779992);
   g_test_exec.Init(GetPointer(g_test_state),779992,_Symbol);
   g_test_manage.Init(779992,_Symbol);
   return INIT_SUCCEEDED;
  }

void OnTick()
  {
   if(g_finished) return;
   string note="";
   if(!g_started)
     {
      g_started=true; g_start_time=TimeCurrent();
      ScpPlan p; ZeroMemory(p);
      p.direction=-1; p.volume=0.02; p.partial_volume=0.01; p.partial_trigger=3; p.breakeven_trigger=2.5;
      double entry=SymbolInfoDouble(_Symbol,SYMBOL_BID),tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
      p.sl=ScpRoundUpToTick(entry+10,tick); p.tp=ScpRoundUpToTick(entry-10,tick); p.invalidation=p.sl;
      p.target_edge_bid=p.tp;
      p.risk_budget=1000; p.atr_m1=1; p.atr_ref=1;
      CheckPrice(g_test_exec.Send(p,note),"mở vị thế kiểm 0,02");
      return;
     }
   if(TimeCurrent()>g_start_time+300)
     { CheckPrice(false,"hết cửa sổ ca kiểm, không suy là đạt"); g_finished=true; return; }
   g_test_exec.Reconcile(note);
   ulong ticket; double vol,entry,sl,tp; int dir; datetime opened;
   bool have=g_test_exec.FindOurPosition(ticket,vol,entry,dir,sl,tp,opened);
   if(have)
     {
      if(g_position_id==0)
        {
         PositionSelectByTicket(ticket);
         g_position_id=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
         g_original_entry=entry; g_original_tp=tp;
        }
      double progress=entry-SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      int action=g_test_manage.Step(NULL,g_test_exec,g_test_state,note);
      if(!g_scaled && action==SCP_MG_PARTIAL)
        {
         g_scaled=true;
         CheckPrice(progress>=3-1e-8,"chỉ chốt phần khi giá thoát đi thuận đủ 3 giá");
         g_test_exec.FindOurPosition(ticket,vol,entry,dir,sl,tp,opened);
         CheckPrice(MathAbs(vol-0.01)<1e-8,"còn đúng 0,01 lot");
         CheckPrice(MathAbs(sl-entry)<SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE),"dừng phần còn lại tại giá vào");
         CheckPrice(tp==g_original_tp,"không kéo xa mục tiêu");
         ScpExec recovered; recovered.Init(GetPointer(g_test_state),779992,_Symbol);
         CheckPrice(recovered.PartialOnce(note)==0,"khởi tạo lại không chốt tiếp 0,01 còn lại");
        }
      return;
     }
   if(g_position_id>0 && g_test_exec.State()==SCP_EX_CLOSED)
     {
      double net=0,last_exit=0; int outs=0; bool last_sl=false;
      if(HistorySelectByPosition(g_position_id))
         for(int i=0;i<HistoryDealsTotal();i++)
           {
            ulong d=HistoryDealGetTicket(i);
            net+=HistoryDealGetDouble(d,DEAL_PROFIT)+HistoryDealGetDouble(d,DEAL_COMMISSION)+
                 HistoryDealGetDouble(d,DEAL_SWAP)+HistoryDealGetDouble(d,DEAL_FEE);
            if(HistoryDealGetInteger(d,DEAL_ENTRY)==DEAL_ENTRY_OUT)
              { outs++; last_exit=HistoryDealGetDouble(d,DEAL_PRICE); last_sl=HistoryDealGetInteger(d,DEAL_REASON)==DEAL_REASON_SL; }
           }
      CheckPrice(g_scaled && outs==2,"hai phần đóng, không có lần chốt lặp");
      CheckPrice(last_sl && MathAbs(last_exit-g_original_entry)<0.01,"phần cuối khớp dừng gần giá vào, sai lệch dưới 0,01 trong dữ liệu ca");
      Print("[SCP_PRICE_TEST] entry=",DoubleToString(g_original_entry,3)," last_exit=",DoubleToString(last_exit,3));
      CheckPrice(net>0,"tổng cả vị thế còn lời trong ca kiểm này");
      Print("[SCP_PRICE_TEST] TOTAL ",g_pass+g_fail," PASS ",g_pass," FAIL ",g_fail," net=",DoubleToString(net,2));
      g_finished=true;
     }
  }

void OnDeinit(const int reason)
  {
   if(!g_finished) CheckPrice(false,"ca chưa hoàn tất");
   Print("[SCP_PRICE_TEST] FINAL PASS ",g_pass," FAIL ",g_fail);
  }

void OnTradeTransaction(const MqlTradeTransaction &t,const MqlTradeRequest &q,const MqlTradeResult &r)
  { g_test_exec.OnTransaction(t,q,r); }
