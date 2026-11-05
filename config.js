/* ==========================================================
   CẤU HÌNH VML COMPANY TRIP (Netlify + Supabase)
   Dán "Project URL" và khoá "anon public" của Supabase vào dưới.
   Chưa dán thì game vẫn chạy offline (có nhân viên giả lập).
   ========================================================== */
window.VML_CONFIG = {
  backend: "supabase",
  supabase: {
    url: "https://xahypshxbykmkywhevnm.supabase.co",
    anonKey: "sb_publishable_bYhLqaYnFyFJH7C8_goR6g_d6GY4wXu"
  },
  game: {
    startMoney: 9000000, // Tiền khởi đầu mỗi ngày. Chơi thật thì đổi thành 0
    dayMinutes: 20,      // Một ngày trong game dài bao nhiêu phút (08:00 → 20:00)
    bots: 0,             // Số nhân viên giả lập khi chạy online (nên để 0)
    testBots: 16         // Số nhân viên giả lập khi chạy offline để test
  }
};
