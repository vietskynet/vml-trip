-- Cập nhật 06.11.2026: cho phép trang trí phòng khách sạn (ban công, cửa sổ, bảng tên)
-- Chạy 1 lần trong Supabase > SQL Editor. Chạy lại nhiều lần cũng không sao.

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
  if s[1] = 'gifts' then
    return n = 3 and s[2] <> u and cur is null and nv is not null and nv ->> 'from' = u and (nv ->> 'amount')::numeric > 0;
  end if;
  if s[1] = 'market' then return s[2] = u; end if;          -- chỉ đăng/huỷ tin rao của mình
  if s[1] = 'deco' then                                     -- ai có giường trong căn đó mới được trang trí
    return n = 4 and ((s[2] in ('villa', 'tent') and s[4] in ('g1', 'g2', 'top', 'door', 'plate'))
                   or (s[2] = 'room' and s[4] in ('bal', 'win', 'plate'))) and public.rt_owns(u, s[2], s[3]);
  end if;
  return false;
end $$;
