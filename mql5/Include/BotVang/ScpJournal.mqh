// ScpJournal.mqh — nhật ký quyết định, vùng và kế hoạch của bot (SPEC mục 16.1).
// Ghi theo sự kiện, không ghi mỗi tick; không ghi tài khoản/mật khẩu/khóa.
#ifndef SCP_JOURNAL_MQH
#define SCP_JOURNAL_MQH

#include "ScpTypes.mqh"
#include "ScpPlan.mqh"

class ScpJournal
  {
private:
   bool              m_ok;
   string            m_folder;
   string            m_symbol;
   string            m_run;
   int               m_fh_dec;
   int               m_fh_plan;
   int               m_fh_zone;
   int               m_fh_exec;

   void              Line(int fh, const string text)
     {
      if(fh == INVALID_HANDLE)
         return;
      FileWriteString(fh, text + "\r\n");
     }

public:
                     ScpJournal()
     {
      m_ok = false;
      m_fh_dec = INVALID_HANDLE;
      m_fh_plan = INVALID_HANDLE;
      m_fh_zone = INVALID_HANDLE;
      m_fh_exec = INVALID_HANDLE;
     }

   bool              Init(const string folder, const string sym, const string run)
     {
      m_folder = folder;
      m_symbol = sym;
      m_run = run;
      if(!FolderCreate(folder, FILE_COMMON))
        {
         // Có thể đã tồn tại; vẫn tiếp tục thử mở file.
        }
      bool exists=FileIsExist(folder+"\\quyet_dinh.csv",FILE_COMMON);
      if(exists && MQLInfoInteger(MQL_TESTER))
        { Print("[SCP][JOURNAL] tên lần chạy đã tồn tại; không ghi đè"); return false; }
      if(exists)
        {
         int check=FileOpen(folder+"\\ke_hoach.csv",FILE_COMMON|FILE_READ|FILE_TXT|FILE_UNICODE|FILE_SHARE_READ);
         if(check==INVALID_HANDLE) return false;
         string header=FileReadString(check); FileClose(check);
         if(StringFind(header,";partial_volume;partial_at;be_at")<0)
           { Print("[SCP][JOURNAL] cấu trúc sổ không tương thích; chọn tên lần chạy mới"); return false; }
        }
      int flags=FILE_COMMON|FILE_READ|FILE_WRITE|FILE_TXT|FILE_UNICODE|FILE_SHARE_READ;
      m_fh_dec = FileOpen(folder + "\\quyet_dinh.csv", flags);
      m_fh_plan = FileOpen(folder + "\\ke_hoach.csv", flags);
      m_fh_zone = FileOpen(folder + "\\vung.csv", flags);
      m_fh_exec = FileOpen(folder + "\\thuc_thi.csv", flags);
      m_ok = (m_fh_dec != INVALID_HANDLE && m_fh_plan != INVALID_HANDLE &&
              m_fh_zone != INVALID_HANDLE && m_fh_exec != INVALID_HANDLE);
      if(m_ok && exists)
        {
         FileSeek(m_fh_dec,0,SEEK_END); FileSeek(m_fh_plan,0,SEEK_END);
         FileSeek(m_fh_zone,0,SEEK_END); FileSeek(m_fh_exec,0,SEEK_END);
        }
      if(m_ok && !exists)
        {
         Line(m_fh_dec, "run;gio_san;ky_hieu;spec;nhanh;chieu;vung;khung;ly_do;chi_tiet");
         Line(m_fh_plan, "plan_id;spec;symbol;episode;nhanh;chieu;vung;khung_vao;khung_quan_ly;boi_canh;luan_diem;gia_gioi_han;dung;chot;rui_ro;loi;ty_le;khoi_luong;han_gui;han_giu;partial_volume;partial_at;be_at");
         Line(m_fh_zone, "zone_id;version;loai;muc;khung_nguon;day;dinh;vai_tro;gio_hinh_thanh;gio_biet;het_tuoi");
         Line(m_fh_exec, "gio_san;loai;plan_id;chi_tiet");
        }
      return m_ok;
     }

   bool              Ready() { return m_ok; }
   void              Flush()
     {
      if(m_fh_dec!=INVALID_HANDLE) FileFlush(m_fh_dec);
      if(m_fh_plan!=INVALID_HANDLE) FileFlush(m_fh_plan);
      if(m_fh_zone!=INVALID_HANDLE) FileFlush(m_fh_zone);
      if(m_fh_exec!=INVALID_HANDLE) FileFlush(m_fh_exec);
     }

   void              Decision(datetime t, const string scenario, int dir, const string zone,
                              const string tf, const string reason, const string detail)
     {
      if(m_fh_dec == INVALID_HANDLE)
         return;
      string safe=detail;
      StringReplace(safe,";",","); StringReplace(safe,"\r"," "); StringReplace(safe,"\n"," ");
      Line(m_fh_dec, m_run + ";" + TimeToString(t, TIME_DATE | TIME_SECONDS) + ";" + m_symbol + ";" +
           SCP_SPEC_VERSION + ";" + scenario + ";" + (dir > 0 ? "MUA" : (dir < 0 ? "BAN" : "-")) + ";" +
           zone + ";" + tf + ";" + reason + ";" + safe);
     }

   void              PlanLine(const ScpPlan &p, const ScpQuote &q)
     {
      if(m_fh_plan == INVALID_HANDLE)
         return;
      Line(m_fh_plan, IntegerToString((int)p.plan_id) + ";" + p.spec_version + ";" + p.symbol + ";" +
           IntegerToString((int)p.episode_id) + ";" + ScpScenarioName(p.scenario) + ";" +
           (p.direction > 0 ? "MUA" : "BAN") + ";" + IntegerToString((int)p.zone_id) + ";" +
           ScpTfName(p.entry_tf) + ";" + ScpTfName(p.management_tf) + ";" + ScpContextName(p.context) + ";" +
           ScpScenarioName(p.scenario) + ";" + DoubleToString(p.entry_price_limit, 8) + ";" +
           DoubleToString(p.sl, 8) + ";" + DoubleToString(p.tp, 8) + ";" +
           DoubleToString(p.expected_risk, 2) + ";" + DoubleToString(p.expected_reward, 2) + ";" +
           DoubleToString(p.net_reward_risk, 3) + ";" + DoubleToString(p.volume, 3) + ";" +
           TimeToString(p.send_deadline, TIME_DATE | TIME_SECONDS) + ";" +
           (p.hold_deadline>0 ? TimeToString(p.hold_deadline, TIME_DATE | TIME_SECONDS) : "DISABLED")+";"+
           DoubleToString(p.partial_volume,4)+";"+DoubleToString(p.partial_trigger,3)+";"+DoubleToString(p.breakeven_trigger,3));
     }

   void              ZoneLine(const ScpZone &z)
     {
      if(m_fh_zone == INVALID_HANDLE)
         return;
      Line(m_fh_zone, IntegerToString((int)z.id) + ";" + IntegerToString(z.version) + ";" +
           IntegerToString((int)z.type) + ";" + IntegerToString((int)z.level) + ";" +
           ScpTfName(z.source_tf) + ";" + DoubleToString(z.bottom, 8) + ";" + DoubleToString(z.top, 8) + ";" +
           IntegerToString((int)z.source_role) + ";" + TimeToString(z.origin_time, TIME_DATE | TIME_SECONDS) + ";" +
           TimeToString(z.known_at, TIME_DATE | TIME_SECONDS) + ";" + TimeToString(z.expires_at, TIME_DATE | TIME_SECONDS));
     }

   void              ExecLine(datetime t, const string kind, long plan_id, const string detail)
     {
      if(m_fh_exec == INVALID_HANDLE)
         return;
      string safe=detail;
      StringReplace(safe,";",","); StringReplace(safe,"\r"," "); StringReplace(safe,"\n"," ");
      Line(m_fh_exec, TimeToString(t, TIME_DATE | TIME_SECONDS) + ";" + kind + ";" +
           IntegerToString((int)plan_id) + ";" + safe);
     }

   void              Finish(const string summary)
     {
      if(!m_ok) return; // khởi tạo thất bại không được ghi đè tổng kết lượt đã có
      if(m_fh_dec != INVALID_HANDLE)
         FileClose(m_fh_dec);
      if(m_fh_plan != INVALID_HANDLE)
         FileClose(m_fh_plan);
      if(m_fh_zone != INVALID_HANDLE)
         FileClose(m_fh_zone);
      if(m_fh_exec != INVALID_HANDLE)
         FileClose(m_fh_exec);
      int fh = FileOpen(m_folder + "\\tong_ket.txt", FILE_COMMON | FILE_WRITE | FILE_TXT | FILE_UNICODE);
      if(fh != INVALID_HANDLE)
        {
         FileWriteString(fh, summary + "\r\n");
         FileClose(fh);
        }
     }
  };

#endif // SCP_JOURNAL_MQH
