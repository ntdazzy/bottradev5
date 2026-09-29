// Ca tích hợp thực thi trong Strategy Tester. Không thể khởi động trên tài khoản demo/thật.
#property strict
#include <BotVang\ScpExec.mqh>
#include <BotVang\ScpSafety.mqh>
#include <BotVang\ScpManage.mqh>

ScpState test_state;
ScpExec ex;
ScpRiskLedger ledger;
ScpManage test_manage;
int phase=0, passed=0, failed=0;
datetime started=0;
bool finished=false;

void Check(bool ok,string name)
  {
   if(ok) passed++; else failed++;
   Print("[SCP_EXEC_TEST] ",ok?"PASS ":"FAIL ",name);
  }

int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER)) return INIT_FAILED;
   test_state.Init(_Symbol,779991);
   ex.Init(GetPointer(test_state),779991,_Symbol);
   ledger.Init(GetPointer(test_state),779991,_Symbol,7,0.25,2,5,8);
   test_manage.Init(779991,_Symbol);
   return INIT_SUCCEEDED;
  }

ScpPlan Plan()
  {
   ScpPlan p; ZeroMemory(p);
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double distance=MathMax(5.0,SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*SymbolInfoDouble(_Symbol,SYMBOL_POINT)*2);
   p.direction=1; p.volume=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN)*(phase==0?2:1);
   p.sl=ScpRoundDownToTick(bid-distance,tick); p.tp=ScpRoundUpToTick(bid+distance,tick);
   p.target_edge_bid=p.tp;
   p.invalidation=p.sl; p.atr_m1=1; p.atr_ref=1;
   p.risk_budget=1000; p.expected_cost=0; p.hold_seconds=300; p.progress_seconds=120;
   p.hold_deadline=TimeCurrent()+300; p.no_progress_deadline=TimeCurrent()+120;
   p.partial_volume=phase==0?SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN):0;
   p.partial_trigger=3; p.breakeven_trigger=2.5;
   return p;
  }

void OnTick()
  {
   if(finished) return;
   string why="";
   if(started==0) started=TimeCurrent();
   if(TimeCurrent()>started+180)
     { Check(false,"hết thời gian kiểm thực thi"); finished=true; return; }
   if(phase==0)
     {
      ScpPlan p=Plan();
      Check(ex.Send(p,why),"gửi lệnh thứ nhất");
      Check(!ex.Send(p,why),"khóa gửi lặp khi đang xử lý");
      phase=1; return;
     }
   ex.Reconcile(why);
   if(phase==1 && ex.HasOurPosition())
     {
      Check(ex.HasPlan(),"giữ đủ kế hoạch bảo vệ");
      ulong ticket; double volume,entry,sl,tp; int dir; datetime opened;
      ex.FindOurPosition(ticket,volume,entry,dir,sl,tp,opened);
      Check(sl>0 && tp>0,"sàn có dừng và chốt");
      test_state.Set(SK_POS_HOLD,(double)(TimeCurrent()-600));
      test_state.Set(SK_POS_PROG,(double)(TimeCurrent()-600));
      Check(test_manage.Step(NULL,ex,test_state,why)==SCP_MG_NONE && ex.HasOurPosition(),
            "hạn giờ cũ không tự đóng vị thế");
      Check(ex.PartialOnce(why)==2,"xác nhận chốt một phần bằng khối lượng thực");
      double remaining=0; double initial=volume;
      ex.FindOurPosition(ticket,remaining,entry,dir,sl,tp,opened);
      Check(MathAbs(remaining-initial*0.5)<1e-8,"0,02 lot còn 0,01 sau chốt nửa");
      Check(ex.PartialOnce(why)==0,"không gửi chốt phần lần hai");
      ScpExec restart; restart.Init(GetPointer(test_state),779991,_Symbol); restart.Reconcile(why);
      Check(restart.HasOurPosition() && restart.HasPlan(),"nhận lại vị thế sau khởi tạo đối tượng");
      Check(restart.PartialOnce(why)==0,"khởi tạo lại không chốt nửa lần nữa");
      double before=sl;
      double invalid=SymbolInfoDouble(_Symbol,SYMBOL_ASK)+100;
      Check(!ex.ModifyProtection(ticket,invalid,tp,why),"sàn từ chối dừng sai phía không bị báo thành công");
      PositionSelectByTicket(ticket);
      Check(PositionGetDouble(POSITION_SL)==before,"giữ dừng sàn khi sửa thất bại");
      phase=4; return;
     }
   if(phase==4 && ex.HasOurPosition())
     {
      int action=test_manage.Step(NULL,ex,test_state,why);
      if(action==SCP_MG_TIGHTEN)
        {
         ulong ticket; double volume,entry,sl,tp; int dir; datetime opened;
         ex.FindOurPosition(ticket,volume,entry,dir,sl,tp,opened);
         Check(sl>=entry-1e-8,"phần còn lại đã có dừng tại giá vào");
         Check(MathAbs(tp-test_state.Get(SK_POS_TGT))<1e-8,"chốt phần và kéo dừng không đổi mục tiêu");
         Check(ex.CloseOurPosition(why),"đóng phần còn lại của lệnh thứ nhất");
         phase=2;
        }
      return;
     }
   if(phase==2 && !ex.HasOurPosition())
     {
      ScpPlan p=Plan();
      Check(ex.Send(p,why),"gửi tiếp sau khi đóng");
      phase=3; return;
     }
   if(phase==3 && ex.HasOurPosition())
     {
      Check(ex.CloseOurPosition(why),"đóng lệnh thứ hai");
      ledger.Update(TimeCurrent());
      test_state.Set(SK_LOCK_DAY,1); test_state.Flush();
      ledger.Update(TimeCurrent());
      Check(ledger.LockedOut(),"khóa lỗ không tự mở khi giá hồi");
      ScpRiskLedger again; again.Init(GetPointer(test_state),779991,_Symbol,7,0.25,2,5,8); again.Update(TimeCurrent());
      Check(again.LockedOut(),"khóa còn sau khởi tạo lại");
      test_state.Set(SK_PLAN_ID,999); test_state.Set(SK_EXEC_STATE,SCP_EX_SENT_UNKNOWN);
      test_state.Set(SK_POS_OPEN,(double)(TimeCurrent()-60)); test_state.Set(SK_ORDER,0); test_state.Flush();
      ScpExec unknown; unknown.Init(GetPointer(test_state),779991,_Symbol); unknown.Reconcile(why);
      Check(unknown.State()==SCP_EX_SENT_UNKNOWN,"không mở khóa chưa rõ sau 30 giây");
      finished=true;
      Print("[SCP_EXEC_TEST] TOTAL ",passed+failed," PASS ",passed," FAIL ",failed);
     }
  }

void OnDeinit(const int reason)
  {
   if(!finished) Check(false,"chưa hoàn thành luồng kiểm");
   Print("[SCP_EXEC_TEST] FINAL PASS ",passed," FAIL ",failed);
  }

void OnTradeTransaction(const MqlTradeTransaction &t,const MqlTradeRequest &q,const MqlTradeResult &r)
  { ex.OnTransaction(t,q,r); }
