// Hàng đợi ưu tiên (đống nhỏ nhất): khóa số thực kèm một mã số nguyên; lấy phần tử có khóa nhỏ nhất, thêm/bớt O(log n).
// Dùng cho lệnh ảo của PhanUngLab (ngưỡng dừng lỗ/chốt lời gần giá nhất) và hàng chờ đối chứng thời điểm (giờ hẹn sớm nhất).
#ifndef BOTVANG_MINHEAP_MQH
#define BOTVANG_MINHEAP_MQH

class CMinHeap
  {
private:
   double            m_key[];
   int               m_id[];
public:
   int               n;

   void              Init(void) { n = 0; ArrayResize(m_key, 0); ArrayResize(m_id, 0); }
   double            TopKey(void) const { return m_key[0]; }
   int               TopId(void) const { return m_id[0]; }

   void              Push(double key, int id)
     {
      if(n >= ArraySize(m_key))
        {
         ArrayResize(m_key, 2 * n + 4096);
         ArrayResize(m_id, 2 * n + 4096);
        }
      int k = n++;
      while(k > 0)
        {
         int p = (k - 1) / 2;
         if(m_key[p] <= key)
            break;
         m_key[k] = m_key[p];
         m_id[k] = m_id[p];
         k = p;
        }
      m_key[k] = key;
      m_id[k] = id;
     }

   // Bỏ phần tử đầu (khóa nhỏ nhất)
   void              Pop(void)
     {
      n--;
      if(n <= 0)
         return;
      double key = m_key[n];
      int id = m_id[n];
      int k = 0;
      while(true)
        {
         int c = 2 * k + 1;
         if(c >= n)
            break;
         if(c + 1 < n && m_key[c + 1] < m_key[c])
            c++;
         if(key <= m_key[c])
            break;
         m_key[k] = m_key[c];
         m_id[k] = m_id[c];
         k = c;
        }
      m_key[k] = key;
      m_id[k] = id;
     }
  };

#endif
