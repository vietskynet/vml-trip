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
    startMoney: 500000,  // Tiền khởi đầu cho người chơi mới (qua ngày mới vẫn giữ ví)
    dayMinutes: 60,      // Một vòng ngày + đêm (24 giờ trong game) dài bao nhiêu phút thật
    nightMinutes: 15,    // Trong đó ban đêm (19:00 → 05:00) dài bao nhiêu phút; còn lại là ban ngày
    bots: 0,             // Số nhân viên giả lập khi chạy online (nên để 0)
    testBots: 16         // Số nhân viên giả lập khi chạy offline để test
  }
};
