-- Cập nhật luật Lâu Đài 06.11.2026: mỗi người chỉ 1 chỗ trong MỖI tháp (được tham gia nhiều tháp).
-- Chạy 1 lần trong Supabase > SQL Editor. Không xoá dữ liệu.

create or replace function public.rt_castle_reserve(tw int) returns jsonb
language plpgsql security definer set search_path = public as $$
declare u text := auth.uid()::text; t bigint := public.now_ms(); dv jsonb; k int; nm text; cnt int;
begin
  if auth.uid() is null then raise exception 'Chưa đăng nhập'; end if;
  if tw is null or tw < 0 or tw > 4 then return jsonb_build_object('ok', false, 'msg', 'Tháp không hợp lệ.'); end if;
  perform pg_advisory_xact_lock(hashtext('castle'));
  perform pg_advisory_xact_lock(hashtext('castle/' || tw));
  if public.rt_bedcount(u) >= 6 then return jsonb_build_object('ok', false, 'msg', 'Bạn đã đủ 6 giường. Bán hoặc trả bớt giường trước.'); end if;
  select val into dv from public.rtdb where path = 'castle/' || tw;
  dv := coalesce(dv, '{}'::jsonb);
  if dv ->> 'done' is not null then return jsonb_build_object('ok', false, 'msg', 'Tháp này đã có liên minh ở.'); end if;
  if exists (select 1 from jsonb_each_text(case when jsonb_typeof(dv -> 's') = 'object' then dv -> 's' else '{}'::jsonb end) b where b.value = u) then
    return jsonb_build_object('ok', false, 'msg', 'Mỗi người chỉ được 1 chỗ trong mỗi tháp.'); end if;
  k := null;
  for i in 0..2 loop
    if coalesce(dv #>> array['s', i::text], '') = '' then k := i; exit; end if;
  end loop;
  if k is null then return jsonb_build_object('ok', false, 'msg', 'Tháp đã đủ người đặt.'); end if;
  select coalesce(r.val ->> 'name', 'Ai đó') into nm from public.rtdb r where r.path = 'players/' || u;
  if jsonb_typeof(dv -> 's') is distinct from 'object' then dv := dv || '{"s":{}}'::jsonb; end if;
  if jsonb_typeof(dv -> 'n') is distinct from 'object' then dv := dv || '{"n":{}}'::jsonb; end if;
  dv := jsonb_set(dv, array['s', k::text], to_jsonb(u));
  dv := jsonb_set(dv, array['n', k::text], to_jsonb(coalesce(nm, 'Ai đó')));
  select count(*) into cnt from jsonb_each_text(dv -> 's') b where b.value <> '';
  if cnt >= 3 then dv := dv || jsonb_build_object('done', t); end if;
  insert into public.rtdb(path, val, upd) values ('castle/' || tw, dv, t)
    on conflict (path) do update set val = excluded.val, upd = excluded.upd;
  return jsonb_build_object('ok', true, 'k', k, 'done', cnt >= 3);
end $$;

