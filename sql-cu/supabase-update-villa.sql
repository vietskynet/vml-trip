-- Khu Villa Riêng (6 lô) + QUẢN LÝ BĐS VILLA (admin). Chạy 1 lần trong Supabase SQL Editor (thay hàm rt_can bản mới nhất, gồm toàn bộ quy tắc cũ).
--  • vh/{1..6}      : chủ lô ghi lô của mình (mua / xây / trang trí). Thiếu thì mua đất bị máy chủ từ chối.
--  • vhlog/{lô}/{id}: NHẬT KÝ lịch sử phát triển lô (mua, xây, nâng tầng, đổi kiểu, nội thất, trả đất). Thiếu thì game vẫn chạy nhưng lịch sử trong admin sẽ trống.
--  • config/vhP     : bảng giá do ADMIN đặt (admin được phép ghi mọi đường dẫn, không cần quy tắc riêng).
-- Đã chạy bản cũ của file này rồi vẫn PHẢI chạy lại để thêm vhlog.
create or replace function public.rt_can(path text, cur jsonb, nv jsonb, docv jsonb) returns boolean
language plpgsql stable security definer set search_path = public as $$
declare s text[] := string_to_array(trim(both '/' from path), '/'); u text := auth.uid()::text; n int;
begin
  if auth.uid() is null then return false; end if;
  if public.is_admin() then return true; end if;
  n := coalesce(array_length(s, 1), 0);
  if n < 2 then return false; end if;
  if s[1] = 'players' then return s[2] = u; end if;
  if s[1] = 'beds' then                                    -- nhận giường trống (tối đa 6) / trả hoặc nhường giường của mình
    return n = 4 and ((cur is null and nv is not null and nv #>> '{}' = u and public.rt_bedcount(u) < 6)
                   or (cur is not null and cur #>> '{}' = u));
  end if;
  if s[1] = 'offers' then
    if s[2] = u then return true; end if;
    if n = 2 then return false; end if;
    return (cur is null and nv is not null and nv ->> 'from' = u)
        or (cur is not null and jsonb_typeof(cur) = 'object' and cur ->> 'from' = u)
        or (n > 3 and docv #>> array[s[3], 'from'] = u);
  end if;
  if s[1] = 'invites' then return n >= 3; end if;
  if s[1] = 'duels' then return docv is null or docv ->> 'a' = u or docv ->> 'b' = u; end if;
  if s[1] = 'tb' then                                      -- Team Building: trưởng nhóm ghi phòng của mình, thành viên chỉ ghi dòng của mình
    if s[2] = u then return true; end if;
    return n = 4 and s[3] in ('m', 'res') and s[4] = u;
  end if;
  if s[1] = 'lm' then                                      -- Vườn Liên Minh: Gốc Chủ ghi cả cây, thành viên chỉ ghi dòng của mình (m = tên, c = tiền đã góp)
    if n = 2 then return (cur is null and nv is not null and nv ->> 'h' = u) or (docv is not null and docv ->> 'h' = u); end if;
    if docv is not null and docv ->> 'h' = u then return true; end if;
    return n = 4 and s[3] in ('m', 'c', 'iv') and s[4] = u;
  end if;
  if s[1] = 'vh' then                                      -- Khu Villa Riêng: chủ lô ghi lô của mình (mua = tạo mới với o = mình)
    if n = 2 then return (cur is null and nv is not null and nv ->> 'o' = u) or (docv is not null and docv ->> 'o' = u); end if;
    return docv is not null and docv ->> 'o' = u;
  end if;
  if s[1] = 'vhlog' then                                   -- nhật ký Khu Villa: mỗi người chỉ GỬI bản ghi mới của mình (nhỏ, không ghi đè)
    return n = 3 and cur is null and nv is not null and nv ->> 'u' = u and length(nv::text) < 400;
  end if;
  if s[1] = 'errlog' then                                  -- nhật ký lỗi game: ai cũng được GỬI bản ghi mới của mình (nhỏ, không ghi đè), chỉ admin xem/xoá
    return n = 2 and cur is null and nv is not null and nv ->> 'u' = u and length(nv::text) < 3000;
  end if;
  if s[1] = 'gifts' then
    return n = 3 and s[2] <> u and cur is null and nv is not null and nv ->> 'from' = u and (nv ->> 'amount')::numeric > 0;
  end if;
  if s[1] = 'skylb' then                                   -- bảng xếp hạng mùa Sky Bar: mỗi người chỉ ghi dòng của mình, điểm chỉ được tăng
    return n = 3 and s[3] = u and nv is not null and (cur is null or (nv ->> 's')::numeric >= (cur ->> 's')::numeric);
  end if;
  if s[1] = 'market' then return s[2] = u; end if;          -- chỉ đăng/huỷ tin rao của mình
  if s[1] = 'deco' then                                     -- ai có giường trong căn đó mới được trang trí
    if s[2] = 'castle' then return n = 4 and s[4] in ('top', 'base', 'plate') and public.rt_castle_member(u, s[3]); end if;
    return n = 4 and ((s[2] in ('villa', 'tent') and s[4] in ('g1', 'g2', 'top', 'door', 'plate', 'in'))
                   or (s[2] = 'room' and s[4] in ('bal', 'win', 'plate', 'in'))) and public.rt_owns(u, s[2], s[3]);
  end if;
  return false;
end $$;
