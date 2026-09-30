// Tổng kết của BotVangLab: ghép cặp sự kiện giả, bảng cân bằng, kết quả theo tập luật
// và theo nhóm, kiểm tra cách ghép (giả so với giả), chuỗi lệnh của bot, kết luận; ghi CSV và HTML.
#ifndef BOTVANG_LABREPORT_MQH
#define BOTVANG_LABREPORT_MQH

#include "LabSim.mqh"
#include "LabStats.mqh"

#define SET_COUNT 13
#define PART_70 3            // phần 70% = 70a + 70b
#define BOOT_ITERS 2000
#define PAIR_MAX 5

string SetName(int s)
  {
   switch(s)
     {
      case 0:  return "Hiệu ứng vùng lật (mọi sự kiện, không lọc)";
      case 1:  return "LUẬT GỐC (§7.1 đủ điều kiện)";
      case 2:  return "Luật gốc lúc bot rảnh (chuỗi lệnh thật)";
      case 3:  return "Luật gốc + bỏ khi B do sàn chênh lệch";
      case 4:  return "Luật gốc + nến chạm đóng mạnh (vị trí đóng ≥ 0,6)";
      case 5:  return "Luật gốc + bỏ khi giá đã chạy > 1,2B";
      case 6:  return "Luật gốc + chỉ trong 24 nến sau lật";
      case 7:  return "Luật gốc + lọc biến động thấp";
      case 8:  return "Luật gốc, hướng lớn chỉ H1";
      case 9:  return "Luật gốc, hướng lớn chỉ H4";
      case 10: return "Vùng còn mới chưa lật (tùy chọn §7.1)";
      case 11: return "Đảo chiều có điều kiện (§10)";
      case 12: return "Đảo chiều mọi lần dính dừng lỗ";
     }
   return "?";
  }

string SetCode(int s)
  {
   string c[SET_COUNT] = {"T1", "GOC", "GOC_RANH", "UV_BSPREAD", "UV_DONGMANH", "UV_CHAYXA", "UV_24NEN", "UV_BIENDONG",
                          "UV_H1", "UV_H4", "VUNG_MOI", "DAO_DK", "DAO_MOI"};
   return s >= 0 && s < SET_COUNT ? c[s] : "?";
  }

string PartName(int p)
  {
   switch(p)
     {
      case 0: return "70a";
      case 1: return "70b";
      case 2: return "30";
      case PART_70: return "70";
     }
   return "?";
  }

string SessionName(int s) { return s == 0 ? "Á" : (s == 1 ? "Âu" : "Mỹ"); }
string TfName(ENUM_TIMEFRAMES tf) { return tf == PERIOD_M15 ? "M15" : (tf == PERIOD_H1 ? "H1" : (tf == PERIOD_H4 ? "H4" : "Ngày")); }

bool InPart(int evPart, int part) { return part == PART_70 ? evPart <= 1 : evPart == part; }

// Sự kiện đo xong và dùng được cho thống kê không (R của lệnh ảo không phụ thuộc kết quả +kB/−1B)
bool Measurable(const LabEvent &e)
  {
   return e.measureDone && e.simDone && e.exitReason != EXIT_UNFINISHED && (e.flags & FL_NOENTRY) == 0;
  }

// Dùng được cho so sánh p₁ thật − giả: cửa sổ đo p₁ không bị cắt vì sàn nghỉ
bool P1Ok(const LabEvent &e) { return Measurable(e) && e.res[0] != RES_CUT; }

// Sự kiện e thuộc tập s không. Áp như nhau cho thật và giả (vùng giả không có điểm và không có "bot bận").
bool InSet(const LabEvent &e, int s, const LabEvent &all[])
  {
   bool flipped = e.type == EV_FLIPPED;
   bool base = flipped && e.flags == 0;
   switch(s)
     {
      case 0:  return flipped && (e.flags & FL_NOENTRY) == 0;
      case 1:  return base;
      case 2:  return base && (e.fake || !e.busy);
      case 3:  return base && (e.cand & CF_BSPREAD) == 0;
      case 4:  return base && (e.cand & CF_CLOSEPOS) == 0;
      case 5:  return base && (e.cand & CF_CHASE) == 0;
      case 6:  return base && (e.cand & CF_WAIT) == 0;
      case 7:  return base && (e.cand & CF_LOWVOL) == 0;
      case 8:  return flipped && (e.flags & ~FL_BIAS) == 0 && (e.cand & CF_BIAS_H1) == 0;
      case 9:  return flipped && (e.flags & ~FL_BIAS) == 0 && (e.cand & CF_BIAS_H4) == 0;
      case 10: return e.type == EV_FRESH && e.flags == 0;
      case 11: return e.type == EV_REVERSE && e.src >= 0 && InSet(all[e.src], 1, all) && e.flags == 0 && e.rev == 0;
      case 12: return e.type == EV_REVERSE && e.src >= 0 && InSet(all[e.src], 0, all) && (e.flags & FL_NOENTRY) == 0;
     }
   return false;
  }

// Kết quả của một tập luật trên một phần dữ liệu
struct SetResult
  {
   int               nReal;          // sự kiện thật đo được
   int               nPaired;        // có đối chứng
   int               days;
   int               nK[LAB_K];      // mẫu số của p_k: bỏ sự kiện có mốc k bị cắt vì sàn nghỉ
   int               win[LAB_K];
   int               tout[LAB_K];
   double            pstar[LAB_K];   // mức hòa vốn trung bình ở chi phí kết luận
   double            wlo[LAB_K];
   double            whi[LAB_K];
   double            fakeP1;         // trung bình p1 của vùng giả đã ghép
   double            d1;             // thật − giả của p1 (trên sự kiện có đối chứng)
   double            d1lo;
   double            d1hi;
   bool              d1ci;
   double            rAll;           // R trung bình (mọi sự kiện đo được), sau chi phí kết luận — tiêu chí 2
   double            rAllLo;
   double            rAllHi;
   bool              rAllCi;
   double            rPair;          // R trung bình trên sự kiện có đối chứng
   double            rlo;
   double            rhi;
   bool              rci;
   double            rFake;
   double            rByCost[5];     // R trung bình mọi sự kiện ở c = 0; 0,1; 0,2; 0,3; 0,5
   bool              relaxedBias;
  };

class CLabReport
  {
private:
   int               m_fakeIdx[];     // chỉ số sự kiện giả, sắp theo giờ chạm
   int               m_nFake;
   double            m_cost;
   double            m_alpha;
   ulong             m_seed;
   string            m_html;
   double            m_costs[5];
   int               m_pairDays;      // cửa sổ tìm đối chứng (ngày lịch) cho vùng M15; khung lớn gấp đôi

   static long       EventKey(const LabEvent &e) { return (long)e.touchTime * 4 + (e.dir > 0 ? 1 : 0) + (e.type == EV_REVERSE ? 2 : 0); }

   void              SortFakes(const LabEvent &all[], int n)
     {
      // Sự kiện giả trùng nến và cùng chiều với một sự kiện thật đi chung đường giá với nó: loại khỏi kho
      long realKeys[];
      int nk = 0;
      for(int i = 0; i < n; i++)
         if(!all[i].fake)
           {
            ArrayResize(realKeys, nk + 1, 1024);
            realKeys[nk++] = EventKey(all[i]);
           }
      ArraySort(realKeys);
      m_nFake = 0;
      coincident = 0;
      overlapExcluded = 0;
      ArrayResize(m_fakeIdx, 0);
      for(int i = 0; i < n; i++)
         if(all[i].fake && P1Ok(all[i]))
           {
            // Vùng giả đang chồng vùng thật lúc chạm: chỉ đếm để báo (vùng thật quá dày; loại hết thì gần như không còn đối chứng).
            // Giữ lại làm đối chứng khiến vùng giả giống vùng thật hơn, tức là khó thấy lợi thế hơn (thận trọng).
            if(all[i].overlapReal)
               overlapExcluded++;
            long key = EventKey(all[i]);
            if(nk > 0 && realKeys[ArrayBsearch(realKeys, key)] == key)
              {
               coincident++;
               continue;
              }
            ArrayResize(m_fakeIdx, m_nFake + 1, 1024);
            m_fakeIdx[m_nFake++] = i;
           }
      // sự kiện được thêm theo thời gian nên gần như đã sắp; chèn trực tiếp cho chắc
      for(int i = 1; i < m_nFake; i++)
        {
         int v = m_fakeIdx[i];
         int j = i - 1;
         for(; j >= 0 && all[m_fakeIdx[j]].touchTime > all[v].touchTime; j--)
            m_fakeIdx[j + 1] = m_fakeIdx[j];
         m_fakeIdx[j + 1] = v;
        }
     }

   static bool       Near(double a, double b) { return b > 0.0 && MathAbs(a / b - 1.0) <= 0.25; }

   // Ghép tối đa 5 sự kiện giả cho sự kiện r: đã đo xong trước lúc chạm thật, trong 5 ngày giao dịch
   // (≈ 7 ngày lịch; vùng H1/H4/ngày: 14 ngày), cùng khung, chiều, phiên, quan hệ hướng lớn, cùng tập luật, cùng phần 70/30,
   // biến động và chênh lệch lúc chạm trong ±25%. Lấy các sự kiện gần nhất.
   int               Pair(const LabEvent &r, int set, const LabEvent &all[], bool relaxBias, int excludeParent, int &out[])
     {
      int m = 0;
      int lookback = (r.tf == PERIOD_M15 ? m_pairDays : 2 * m_pairDays) * 86400;
      // vị trí cuối cùng có giờ chạm < giờ chạm thật
      int lo = 0, hi = m_nFake - 1, pos = -1;
      while(lo <= hi)
        {
         int mid = (lo + hi) / 2;
         if(all[m_fakeIdx[mid]].touchTime < r.touchTime)
           {
            pos = mid;
            lo = mid + 1;
           }
         else
            hi = mid - 1;
        }
      for(int j = pos; j >= 0 && m < PAIR_MAX; j--)
        {
         int fi = m_fakeIdx[j];
         if(all[fi].touchTime < r.touchTime - lookback)
            break;
         if(all[fi].windowEnd > r.touchTime || all[fi].tf != r.tf || all[fi].dir != r.dir || all[fi].session != r.session)
            continue;
         if(!relaxBias && all[fi].biasRel != r.biasRel)
            continue;
         if((all[fi].part == 2) != (r.part == 2) || all[fi].parentId == excludeParent || all[fi].zoneId == r.zoneId)
            continue;
         if(!Near(all[fi].atrM5, r.atrM5) || !Near(all[fi].spreadTouch, r.spreadTouch) || !InSet(all[fi], set, all))
            continue;
         out[m++] = fi;
        }
      return m;
     }

   double            Rnet(const LabEvent &e, double c) const { return e.rGross - c / e.B; }
   static double     Win1(const LabEvent &e) { return e.res[0] == RES_WIN ? 1.0 : 0.0; }

   // Tỉ lệ ghép được của một tập (phần 70%), để quyết định có bỏ khóa hướng lớn không
   double            PairRate(int set, const LabEvent &all[], int n, bool relaxBias)
     {
      int tot = 0, ok = 0;
      int out[PAIR_MAX];
      for(int i = 0; i < n; i++)
        {
         if(all[i].fake || !P1Ok(all[i]) || all[i].part > 1 || !InSet(all[i], set, all))
            continue;
         tot++;
         if(Pair(all[i], set, all, relaxBias, all[i].zoneId, out) > 0)
            ok++;
        }
      return tot > 0 ? (double)ok / tot : 1.0;
     }

public:
   int               coincident;     // số sự kiện giả bị loại vì trùng nến, cùng chiều với sự kiện thật
   int               overlapExcluded; // số sự kiện giả mà vùng giả đang chồng lên vùng thật lúc chạm (chỉ báo, không loại)
   bool              relax[SET_COUNT];
   bool              placeboBad[SET_COUNT];   // phép thử giả so với giả lệch rõ (khoảng tin cậy không chứa 0)
   SetResult         res[SET_COUNT][4];

   void              Init(double costReport, double alpha, ulong seed, int pairDays)
     {
      m_pairDays = pairDays;
      m_cost = costReport;
      m_alpha = alpha;
      m_seed = seed;
      double cs[5] = {0.0, 0.1, 0.2, 0.3, 0.5};
      ArrayCopy(m_costs, cs);
     }

   void              Compute(const LabEvent &all[], int n)
     {
      SortFakes(all, n);
      for(int s = 0; s < SET_COUNT; s++)
        {
         relax[s] = PairRate(s, all, n, false) < 0.8;
         for(int p = 0; p < 4; p++)
            ComputeOne(s, p, all, n);
        }
     }

   void              ComputeOne(int s, int part, const LabEvent &all[], int n)
     {
      SetResult r;
      ZeroMemory(r);
      r.relaxedBias = relax[s];
      CSamples d1, rp, ra;
      double fp = 0.0, fr = 0.0;
      double rc[5];
      ArrayInitialize(rc, 0.0);
      int out[PAIR_MAX];
      for(int i = 0; i < n; i++)
        {
         if(all[i].fake || !Measurable(all[i]) || !InPart(all[i].part, part) || !InSet(all[i], s, all))
            continue;
         r.nReal++;
         for(int k = 0; k < LAB_K; k++)
           {
            if(all[i].res[k] == RES_CUT)
               continue;
            r.nK[k]++;
            if(all[i].res[k] == RES_WIN)
               r.win[k]++;
            if(all[i].res[k] == RES_TIMEOUT)
               r.tout[k]++;
            r.pstar[k] += BreakEvenP(all[i].B, m_cost, k + 1);
           }
         ra.Add(all[i].vnDay, Rnet(all[i], m_cost));
         for(int c = 0; c < 5; c++)
            rc[c] += Rnet(all[i], m_costs[c]);
         int m = P1Ok(all[i]) ? Pair(all[i], s, all, relax[s], all[i].zoneId, out) : 0;
         if(m == 0)
            continue;
         r.nPaired++;
         double fw = 0.0, frr = 0.0;
         for(int j = 0; j < m; j++)
           {
            fw += Win1(all[out[j]]);
            frr += Rnet(all[out[j]], m_cost);
           }
         fw /= m;
         frr /= m;
         fp += fw;
         fr += frr;
         d1.Add(all[i].vnDay, Win1(all[i]) - fw);
         rp.Add(all[i].vnDay, Rnet(all[i], m_cost));
        }
      double z = NormInv(1.0 - m_alpha / 2.0);
      int rank = BootRank(BOOT_ITERS, m_alpha);
      for(int k = 0; k < LAB_K; k++)
        {
         if(r.nK[k] > 0)
            r.pstar[k] /= r.nK[k];
         Wilson(r.win[k], r.nK[k], z, r.wlo[k], r.whi[k]);
        }
      r.days = ra.Days();
      r.rAll = ra.Mean();
      r.rAllCi = r.days >= 20 && r.nReal >= 30 && ra.CI(BOOT_ITERS, RngMix(m_seed, (ulong)(2000 + s * 16 + part)), rank, r.rAllLo, r.rAllHi);
      for(int c = 0; c < 5; c++)
         r.rByCost[c] = r.nReal > 0 ? rc[c] / r.nReal : 0.0;
      if(r.nPaired > 0)
        {
         r.fakeP1 = fp / r.nPaired;
         r.rFake = fr / r.nPaired;
         r.d1 = d1.Mean();
         r.rPair = rp.Mean();
         bool enough = d1.Days() >= 20 && r.nPaired >= 30;
         r.d1ci = enough && d1.CI(BOOT_ITERS, RngMix(m_seed, (ulong)(s * 16 + part)), rank, r.d1lo, r.d1hi);
         r.rci = enough && rp.CI(BOOT_ITERS, RngMix(m_seed, (ulong)(1000 + s * 16 + part)), rank, r.rlo, r.rhi);
        }
      res[s][part] = r;
     }

   // Kiểm tra cách ghép: coi sự kiện giả là thật, ghép với sự kiện giả khác (khác vùng thật mẹ). Kỳ vọng ≈ 0.
   void              Placebo(int s, int part, const LabEvent &all[], int n, int &nOut, double &d, double &lo, double &hi, bool &ci)
     {
      CSamples x;
      int out[PAIR_MAX];
      for(int i = 0; i < n; i++)
        {
         if(!all[i].fake || !P1Ok(all[i]) || !InPart(all[i].part, part) || !InSet(all[i], s, all))
            continue;
         int m = Pair(all[i], s, all, relax[s], all[i].parentId, out);
         if(m == 0)
            continue;
         double fw = 0.0;
         for(int j = 0; j < m; j++)
            fw += Win1(all[out[j]]);
         x.Add(all[i].vnDay, Win1(all[i]) - fw / m);
        }
      nOut = x.Count();
      d = x.Mean();
      ci = nOut >= 30 && x.CI(BOOT_ITERS, RngMix(m_seed, 777), BootRank(BOOT_ITERS, 0.05), lo, hi);
     }

   // ---------- HTML ----------
   void              H(const string s) { m_html += s + "\n"; }
   static string     P(double x) { return DoubleToString(100.0 * x, 1) + "%"; }
   static string     F(double x, int d = 2) { return DoubleToString(x, d); }

   string            ResultRow(int s, int part)
     {
      SetResult r = res[s][part];
      string row = "<tr><td>" + SetName(s) + "</td><td>" + PartName(part) + "</td><td>" + (string)r.nReal + "</td><td>"
                   + (string)r.nPaired + "</td><td>" + (string)r.days + "</td>";
      for(int k = 0; k < LAB_K; k++)
        {
         double pk = r.nK[k] > 0 ? (double)r.win[k] / r.nK[k] : 0.0;
         row += "<td>" + P(pk) + "<br><small>" + P(r.wlo[k]) + "–" + P(r.whi[k]) + " | hòa vốn " + P(r.pstar[k]) + "</small></td>";
        }
      row += "<td>" + (r.nPaired > 0 ? P(r.fakeP1) : "-") + "</td>";
      row += "<td>" + (r.nPaired > 0 ? (r.d1 >= 0 ? "+" : "") + F(100.0 * r.d1, 1) + " điểm" : "-")
             + (r.d1ci ? "<br><small>" + F(100.0 * r.d1lo, 1) + " … " + F(100.0 * r.d1hi, 1) + "</small>" : (r.nPaired > 0 ? "<br><small>ít dữ liệu</small>" : "")) + "</td>";
      row += "<td>" + F(r.rAll, 3) + (r.rAllCi ? "<br><small>" + F(r.rAllLo, 3) + " … " + F(r.rAllHi, 3) + "</small>" : "") + "</td><td>" + (r.nPaired > 0 ? F(r.rPair, 3) + (r.rci ? "<br><small>" + F(r.rlo, 3) + " … " + F(r.rhi, 3) + "</small>" : "") : "-")
             + "</td><td>" + (r.nPaired > 0 ? F(r.rFake, 3) : "-") + "</td>";
      row += "<td><small>" + F(r.rByCost[0], 3) + " / " + F(r.rByCost[1], 3) + " / " + F(r.rByCost[2], 3) + " / " + F(r.rByCost[3], 3) + " / " + F(r.rByCost[4], 3) + "</small></td>";
      row += "<td>" + (r.relaxedBias ? "bỏ khóa hướng lớn" : "") + "</td></tr>";
      return row;
     }

   // Tiêu chí 3: cả 70a và 70b đều có thật − giả (p₁) > 0 và R sau chi phí (mọi sự kiện) > 0
   bool              Crit3(int s)
     {
      for(int p = 0; p <= 1; p++)
         if(res[s][p].nPaired == 0 || res[s][p].d1 <= 0.0 || res[s][p].rAll <= 0.0)
            return false;
      return true;
     }

   // Kết luận cho một tập luật theo thứ tự
   string            Verdict(int s, bool holdoutOpen, bool locked)
     {
      if(placeboBad[s])
         return "KHÔNG DÙNG ĐƯỢC: phép thử giả so với giả lệch rõ, so sánh với vùng giả chưa đáng tin";
      if(!holdoutOpen)
         return Crit3(s) ? "Qua tiêu chí 3 ở phần 70% → có thể khóa để kiểm tra phần 30%"
                         : "Không qua tiêu chí 3 ở phần 70% → không đưa vào kiểm tra";
      if(!locked)
         return "Không khóa trước → chỉ để xem, không kết luận";
      SetResult r = res[s][2];
      if(!Crit3(s))
         return "KHÔNG ĐƯA VÀO KIỂM TRA (không qua tiêu chí 3)";
      string why = "";
      bool c1 = r.d1ci && r.d1lo > 0.0 && r.d1 >= 0.03;
      bool c2 = r.rAllCi && r.rAllLo > 0.0;
      if(!c1)
         why += " hơn vùng giả chưa rõ ràng;";
      if(!c2)
         why += " chưa lời chắc chắn sau phí;";
      if(r.nReal < 300)
         return "CHƯA ĐỦ DỮ LIỆU (" + (string)r.nReal + "/300 sự kiện, " + (string)r.nPaired + " có đối chứng), giữ TẮT."
                + (r.rAllCi && r.rAllHi < 0.0 ? " Kết quả theo R đã âm rõ ràng." : "");
      return c1 && c2 ? "GIỮ, đề nghị bật" : "BỎ: đo đủ nhưng không thấy lợi thế rõ:" + why;
     }

   // Bảng cân bằng: sự kiện thật có đối chứng so với các sự kiện giả đã ghép (mỗi sự kiện giả nặng 1/m).
   void              Balance(int s, int part, const LabEvent &all[], int n)
     {
      // 0–2 phiên, 3–5 hướng lớn (cùng/ngược/không rõ), 6–9 khung
      double pr[10], pf[10];
      ArrayInitialize(pr, 0.0);
      ArrayInitialize(pf, 0.0);
      // số: biến động M5, chênh lệch lúc chạm, B, B/chênh lệch, nến từ lật/tạo tới chạm, độ rộng/biến động vùng, số vùng chồng
      double sr[7], sr2[7], sf[7], sf2[7];
      ArrayInitialize(sr, 0.0);
      ArrayInitialize(sr2, 0.0);
      ArrayInitialize(sf, 0.0);
      ArrayInitialize(sf2, 0.0);
      int nr = 0, nIn = 0;
      double mSum = 0.0;
      int out[PAIR_MAX];
      for(int i = 0; i < n; i++)
        {
         if(all[i].fake || !Measurable(all[i]) || !InPart(all[i].part, part) || !InSet(all[i], s, all))
            continue;
         nIn++;
         int m = P1Ok(all[i]) ? Pair(all[i], s, all, relax[s], all[i].zoneId, out) : 0;
         if(m == 0)
            continue;
         nr++;
         mSum += m;
         AddBal(all[i], 1.0, pr, sr, sr2);
         for(int j = 0; j < m; j++)
            AddBal(all[out[j]], 1.0 / m, pf, sf, sf2);
        }
      H("<h3>Bảng cân bằng: " + SetName(s) + ", phần " + PartName(part) + "</h3>");
      H("<p>Sự kiện thật: " + (string)nIn + "; có đối chứng: " + (string)nr + " (" + (nIn > 0 ? P((double)nr / nIn) : "-")
        + "); trung bình " + (nr > 0 ? F(mSum / nr, 1) : "0") + " sự kiện giả mỗi sự kiện thật."
        + (nIn > 0 && nr < 0.7 * nIn ? " <b>CẢNH BÁO: hơn 30% sự kiện thật không có đối chứng.</b>" : "") + "</p>");
      if(nr == 0)
         return;
      H("<table><tr><th>Dòng</th><th>Thật</th><th>Giả</th><th>Chênh</th><th>Lệch?</th></tr>");
      string names[10] = {"Phiên Á", "Phiên Âu", "Phiên Mỹ", "Cùng hướng lớn", "Ngược hướng lớn", "Hướng lớn không rõ",
                          "Khung M15", "Khung H1", "Khung H4", "Đỉnh/đáy ngày"};
      for(int k = 0; k < 10; k++)
        {
         double a = pr[k] / nr, b = pf[k] / nr;
         H("<tr><td>" + names[k] + "</td><td>" + P(a) + "</td><td>" + P(b) + "</td><td>" + F(100.0 * (a - b), 1)
           + " điểm</td><td>" + (MathAbs(a - b) > 0.10 ? "CÓ" : "") + "</td></tr>");
        }
      string nn[7] = {"Biến động M5 lúc chạm", "Chênh lệch lúc chạm", "B", "B / chênh lệch", "Nến từ lật (hoặc tạo) tới chạm",
                      "Độ rộng dải / biến động vùng", "Số vùng thật chồng lên"};
      for(int k = 0; k < 7; k++)
        {
         double ma = sr[k] / nr, mb = sf[k] / nr;
         double va = MathMax(0.0, sr2[k] / nr - ma * ma), vb = MathMax(0.0, sf2[k] / nr - mb * mb);
         double sd = MathSqrt((va + vb) / 2.0);
         double smd = sd > 0.0 ? MathAbs(ma - mb) / sd : 0.0;
         H("<tr><td>" + nn[k] + " (trung bình)</td><td>" + F(ma, 3) + "</td><td>" + F(mb, 3) + "</td><td>" + F(ma - mb, 3)
           + "</td><td>" + (smd > 0.1 ? "CÓ (" + F(smd, 2) + ")" : "") + "</td></tr>");
        }
      H("</table>");
     }

   static void       AddBal(const LabEvent &e, double w, double &p[], double &s[], double &s2[])
     {
      p[e.session] += w;
      p[e.biasRel == 1 ? 3 : (e.biasRel == -1 ? 4 : 5)] += w;
      p[e.tf == PERIOD_M15 ? 6 : (e.tf == PERIOD_H1 ? 7 : (e.tf == PERIOD_H4 ? 8 : 9))] += w;
      double v[7];
      v[0] = e.atrM5;
      v[1] = e.spreadTouch;
      v[2] = e.B;
      v[3] = e.spreadEntry > 0.0 ? e.B / e.spreadEntry : 0.0;
      v[4] = e.type == EV_FLIPPED ? e.barsFromFlip : e.barsFromCreate;
      v[5] = e.zoneAtr > 0.0 ? (e.hi - e.lo) / e.zoneAtr : 0.0;
      v[6] = e.conf;
      for(int k = 0; k < 7; k++)
        {
         s[k] += w * v[k];
         s2[k] += w * v[k] * v[k];
        }
     }

   // Nhóm để xem — không dùng để giữ luật
   static int        GroupOf(const LabEvent &e, int g)
     {
      switch(g)
        {
         case 0: return e.session;
         case 1: return e.biasRel == 1 ? 0 : (e.biasRel == -1 ? 1 : 2);
         case 2: return e.tf == PERIOD_M15 ? 0 : (e.tf == PERIOD_H1 ? 1 : (e.tf == PERIOD_H4 ? 2 : 3));
         case 3: return e.scorePre <= 3 ? 0 : (e.scorePre >= 7 ? 4 : e.scorePre - 3);
         case 4: return e.round;
         case 5: return e.bBySpread ? 1 : 0;
         case 6: return (int)e.kind;
         case 7: return MathMin(e.bouncesBeforeFlip, 3);
        }
      return 0;
     }

   static string     GroupLabel(int g, int v)
     {
      switch(g)
        {
         case 0: return "Phiên " + SessionName(v);
         case 1: return v == 0 ? "Cùng hướng lớn" : (v == 1 ? "Ngược hướng lớn" : "Hướng lớn không rõ");
         case 2: return v == 0 ? "Khung M15" : (v == 1 ? "Khung H1" : (v == 2 ? "Khung H4" : "Đỉnh/đáy ngày"));
         case 3: return v == 0 ? "Điểm ≤ 3" : (v == 4 ? "Điểm ≥ 7" : "Điểm " + (string)(v + 3));
         case 4: return v == 0 ? "Không có số tròn" : (v == 1 ? "Có xx50" : "Có xx00");
         case 5: return v == 0 ? "B do biến động (ATR)" : "B do sàn chênh lệch";
         case 6: return v == 0 ? "Loại A/V" : (v == 1 ? "Loại Gap" : (v == 2 ? "Loại đỉnh/đáy xoay" : "Loại đỉnh/đáy ngày"));
         case 7: return v == 3 ? "Bật thật trước lật ≥ 3" : "Bật thật trước lật " + (string)v;
        }
      return "";
     }

   void              Groups(int s, int part, const LabEvent &all[], int n)
     {
      H("<h3>Theo nhóm: " + SetName(s) + ", phần " + PartName(part) + " (chỉ để xem)</h3>");
      H("<table><tr><th>Nhóm</th><th>N</th><th>p₁ thật</th><th>Có đối chứng</th><th>Thật − giả (p₁)</th><th>R trung bình (c=" + F(m_cost, 2) + ")</th></tr>");
      int sizes[8] = {3, 3, 4, 5, 3, 2, 4, 4};
      int out[PAIR_MAX];
      for(int g = 0; g < 8; g++)
         for(int v = 0; v < sizes[g]; v++)
           {
            int cnt = 0, np = 0;
            double w = 0.0, d = 0.0, rr = 0.0;
            for(int i = 0; i < n; i++)
              {
               if(all[i].fake || !Measurable(all[i]) || !InPart(all[i].part, part) || !InSet(all[i], s, all) || GroupOf(all[i], g) != v)
                  continue;
               cnt++;
               w += Win1(all[i]);
               rr += Rnet(all[i], m_cost);
               int m = P1Ok(all[i]) ? Pair(all[i], s, all, relax[s], all[i].zoneId, out) : 0;
               if(m == 0)
                  continue;
               double fw = 0.0;
               for(int j = 0; j < m; j++)
                  fw += Win1(all[out[j]]);
               d += Win1(all[i]) - fw / m;
               np++;
              }
            if(cnt == 0)
               continue;
            H("<tr><td>" + GroupLabel(g, v) + "</td><td>" + (string)cnt + (cnt < 30 ? " <small>(ít)</small>" : "") + "</td><td>" + P(w / cnt)
              + "</td><td>" + (string)np + "</td><td>" + (np > 0 ? F(100.0 * d / np, 1) + " điểm" : "-") + "</td><td>" + F(rr / cnt, 3) + "</td></tr>");
           }
      H("</table>");
     }

   // Chuỗi lệnh của bot (luật gốc lúc rảnh): R mỗi lệnh, chuỗi thua dài nhất, kiểm tra chuỗi (các lần thua có đi liền nhau không)
   void              BotSequence(int part, const LabEvent &all[], int n)
     {
      int cnt = 0, wins = 0, runs = 0, streak = 0, maxStreak = 0, prev = -1;
      double sum = 0.0, peak = 0.0, eq = 0.0, dd = 0.0;
      CSamples x;
      for(int i = 0; i < n; i++)
        {
         if(all[i].fake || !Measurable(all[i]) || !InPart(all[i].part, part) || !InSet(all[i], 2, all))
            continue;
         double r = Rnet(all[i], m_cost);
         x.Add(all[i].vnDay, r);
         cnt++;
         sum += r;
         eq += r;
         peak = MathMax(peak, eq);
         dd = MathMax(dd, peak - eq);
         int w = r > 0.0 ? 1 : 0;
         wins += w;
         if(w != prev)
            runs++;
         prev = w;
         streak = w == 0 ? streak + 1 : 0;
         maxStreak = MathMax(maxStreak, streak);
        }
      H("<h3>Chuỗi lệnh của bot (luật gốc, chỉ vào khi rảnh), phần " + PartName(part) + "</h3>");
      if(cnt == 0)
        {
         H("<p>Không có lệnh.</p>");
         return;
        }
      int losses = cnt - wins;
      double mu = 2.0 * wins * losses / cnt + 1.0;
      double var = cnt > 1 ? (mu - 1.0) * (mu - 2.0) / (cnt - 1) : 0.0;
      double zr = var > 0.0 ? (runs - mu) / MathSqrt(var) : 0.0;
      H("<p>Số lệnh: " + (string)cnt + " trong " + (string)x.Days() + " ngày (" + F((double)cnt / MathMax(1, x.Days()), 2)
        + " lệnh/ngày có lệnh). Lệnh lời: " + P((double)wins / cnt) + ". R trung bình: " + F(sum / cnt, 3) + ", tổng R: " + F(sum, 1)
        + ", sụt lớn nhất: " + F(dd, 1) + " R. Chuỗi thua dài nhất: " + (string)maxStreak + " lệnh. Kiểm tra chuỗi: z = " + F(zr, 2)
        + (zr < -1.96 ? " → các lần thua có xu hướng đi liền nhau (nên giữ phanh)" : " → không thấy thua đi liền nhau hơn ngẫu nhiên (phanh không có cơ sở)")
        + ".</p>");
     }

   // ---------- CSV ----------
   static int        OpenUtf8(const string name)
     {
      int h = FileOpen(name, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON, 0, CP_UTF8);
      if(h != INVALID_HANDLE)
         FileWriteString(h, ShortToString(0xFEFF));
      return h;
     }

   static string     D(double x, int d) { return DoubleToString(x, d); }

   bool              WriteEvents(const string folder, const LabEvent &all[], int n, int digits)
     {
      int h = OpenUtf8(folder + "su_kien.csv");
      if(h == INVALID_HANDLE)
         return false;
      FileWriteString(h, "id,gia,loai,nguon,phan,ngay_vn,gio_cham_san,phut_vn,phien,khung,kieu_vung,chieu,muc,mep_duoi,mep_tren,atr_vung,"
                      "diem_truoc,diem_sau,hop_luu,bat_truoc_lat,nen_tu_lat,nen_tu_tao,vung_trung,nen_tao_manh,so_tron,vi_tri_dong,"
                      "cach_mep_B,huong_lon,quan_he_huong,atr_m5,cl_cham,cl_vao,gia_vao,B,B_do_cl,loc,ung_vien,dao,bot_chon,bot_ban,"
                      "kq1,kq2,kq3,nen_kq1,nen_kq2,nen_kq3,R_cuoi_cua_so,ly_do_thoat,gia_thoat,gio_thoat,R_gop,nhay_B,so_lan_doi,"
                      "tai_can,chong_vung_that,trong_tap\r\n");
      for(int i = 0; i < n; i++)
        {
         const LabEvent e = all[i];
         string sets = "";
         for(int s = 0; s < SET_COUNT; s++)
            if(InSet(e, s, all))
               sets += SetCode(s) + " ";
         string line = (string)e.id + "," + (e.fake ? "1" : "0") + "," + (string)e.type + "," + (string)e.src + "," + (string)e.part + ","
                       + (string)e.vnDay + "," + TimeToString(e.touchTime, TIME_DATE | TIME_MINUTES) + "," + (string)e.vnMinute + ","
                       + (string)e.session + "," + TfName(e.tf) + "," + (string)(int)e.kind + "," + (string)e.dir + ","
                       + D(e.level, digits) + "," + D(e.lo, digits) + "," + D(e.hi, digits) + "," + D(e.zoneAtr, 3) + ","
                       + (string)e.scorePre + "," + (string)e.scorePost + "," + (string)e.conf + "," + (string)e.bouncesBeforeFlip + ","
                       + (string)e.barsFromFlip + "," + (string)e.barsFromCreate + "," + (string)e.dupCount + "," + (e.strongOrigin ? "1" : "0") + ","
                       + (string)e.round + "," + D(e.closePos, 2) + "," + D(e.chaseB, 2) + "," + (string)e.bias + "," + (string)e.biasRel + ","
                       + D(e.atrM5, 3) + "," + D(e.spreadTouch, 3) + "," + D(e.spreadEntry, 3) + "," + D(e.entry, digits) + ","
                       + D(e.B, 3) + "," + (e.bBySpread ? "1" : "0") + "," + (string)e.flags + "," + (string)e.cand + "," + (string)e.rev + ","
                       + (e.chosen ? "1" : "0") + "," + (e.busy ? "1" : "0") + ","
                       + (string)e.res[0] + "," + (string)e.res[1] + "," + (string)e.res[2] + ","
                       + (string)e.resBars[0] + "," + (string)e.resBars[1] + "," + (string)e.resBars[2] + "," + D(e.endR, 3) + ","
                       + (string)e.exitReason + "," + D(e.exitPrice, digits) + "," + TimeToString(e.exitTime, TIME_DATE | TIME_SECONDS) + ","
                       + D(e.rGross, 3) + "," + D(e.jumpB, 3) + "," + (string)e.slMoves + "," + (e.oppEdge > 0.0 ? "1" : "0") + "," + (e.overlapReal ? "1" : "0") + "," + sets + "\r\n";
         FileWriteString(h, line);
        }
      FileClose(h);
      h = OpenUtf8(folder + "loi_lo_tam.csv");
      if(h == INVALID_HANDLE)
         return false;
      string head = "id";
      for(int b = 1; b <= LAB_BARS; b++)
         head += ",loi_" + (string)b;
      for(int b = 1; b <= LAB_BARS; b++)
         head += ",lo_" + (string)b;
      FileWriteString(h, head + "\r\n");
      for(int i = 0; i < n; i++)
        {
         if(all[i].fake || !all[i].measureDone)
            continue;
         string line = (string)all[i].id;
         for(int b = 0; b < LAB_BARS; b++)
            line += "," + D(all[i].mfe[b], 3);
         for(int b = 0; b < LAB_BARS; b++)
            line += "," + D(all[i].mae[b], 3);
         FileWriteString(h, line + "\r\n");
        }
      FileClose(h);
      return true;
     }

   string            Html(void) const { return m_html; }
   void              ResetHtml(void) { m_html = ""; }
  };

#endif
