// Bộ sinh số ngẫu nhiên riêng của BotVangLab (SplitMix64). Cùng hạt giống cho ra cùng dãy số,
// không dùng chung dòng số với MathRand, nên vị trí vùng giả và bootstrap chạy lại luôn ra cùng kết quả.
#ifndef BOTVANG_LABRANDOM_MQH
#define BOTVANG_LABRANDOM_MQH

ulong RngMix(ulong h, ulong v)
  {
   ulong z = h ^ (v + 0x9E3779B97F4A7C15 + (h << 6) + (h >> 2));
   z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9;
   z = (z ^ (z >> 27)) * 0x94D049BB133111EB;
   return z ^ (z >> 31);
  }

class CRng
  {
private:
   ulong             m_s;
public:
   void              Seed(ulong s) { m_s = s; }
   ulong             Next(void)
     {
      m_s += 0x9E3779B97F4A7C15;
      ulong z = m_s;
      z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9;
      z = (z ^ (z >> 27)) * 0x94D049BB133111EB;
      return z ^ (z >> 31);
     }
   double            Uniform(void) { return (double)(Next() >> 11) / 9007199254740992.0; }   // [0; 1)
   int               Below(int n) { return (int)(Next() % (ulong)n); }
  };

#endif
