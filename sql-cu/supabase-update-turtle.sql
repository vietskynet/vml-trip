-- ============================================================================
-- ĐUA RÙA — trung tâm cá cược (chạy 1 lần trong Supabase → SQL Editor)
-- Luật: 1 vòng đua = 150 s (40 s đặt cược + ~95 s đua 2 vòng hồ + nghỉ).
--   · mỗi cược tối đa 20.000.000₫ (tối thiểu 100.000₫)
--   · tối đa 5 lượt / 24 giờ / người, hai lượt cách nhau ít nhất 3 phút
--   · chọn 1 con (thắng) hoặc 2 trên 10 con (cả hai về nhất nhì)
-- Kết quả do máy chủ bốc ngẫu nhiên, người chơi không tính trước được.
-- ============================================================================
create table if not exists public.turtle_rounds (
  rnd bigint primary key,
  ord int[] not null,
  ts bigint not null
);
create table if not exists public.turtle_bets (
  id bigserial primary key,
  uid uuid not null,
  name text,
  rnd bigint not null,
  picks int[] not null,
  amount bigint not null,
  odds numeric not null,
  ts bigint not null,
  settled boolean not null default false,
  win boolean,
  payout bigint not null default 0,
  ord int[],
  sts bigint
);
create index if not exists turtle_bets_uid_idx on public.turtle_bets(uid, ts desc);
create index if not exists turtle_bets_ts_idx on public.turtle_bets(ts desc);
alter table public.turtle_rounds enable row level security;
alter table public.turtle_bets enable row level security;

-- sức mạnh 10 con rùa (cùng bảng với client: TW trong index.html)
create or replace function public.turtle_w() returns numeric[]
language sql immutable as $$ select array[16,14,12,10,9,8,7,6,5,4]::numeric[] $$;

create or replace function public.turtle_odds(picks int[]) returns numeric
language plpgsql immutable as $$
declare w numeric[] := public.turtle_w(); s numeric := 0; x numeric; pa numeric; pb numeric; q numeric; o numeric;
begin
  foreach x in array w loop s := s + x; end loop;
  if array_length(picks, 1) = 1 then
    x := w[picks[1] + 1] / s; o := 0.9 / x; return round(least(greatest(o, 1.2), 30), 2);
  end if;
  pa := w[picks[1] + 1] / s; pb := w[picks[2] + 1] / s;
  q := pa * pb / (1 - pa) + pb * pa / (1 - pb);
  return round(least(greatest(0.9 / q, 1.5), 60), 2);
end $$;

-- bốc thứ tự về đích (chỉ gọi khi vòng đã hết giờ cược)
create or replace function public.turtle_draw() returns int[]
language plpgsql volatile as $$
declare w numeric[] := public.turtle_w(); left_ int[] := array[0,1,2,3,4,5,6,7,8,9]; res int[] := '{}'; tot numeric; r numeric; acc numeric; k int; pick int;
begin
  while array_length(left_, 1) > 0 loop
    tot := 0; foreach k in array left_ loop tot := tot + w[k + 1]; end loop;
    r := random() * tot; acc := 0; pick := left_[1];
    foreach k in array left_ loop acc := acc + w[k + 1]; if r <= acc then pick := k; exit; end if; end loop;
    res := res || pick; left_ := array_remove(left_, pick);
  end loop;
  return res;
end $$;

create or replace function public.turtle_round_ord(r bigint) returns int[]
language plpgsql security definer set search_path = public as $$
declare o int[];
begin
  perform pg_advisory_xact_lock(hashtext('turtle/' || r::text));
  select ord into o from public.turtle_rounds where rnd = r;
  if o is null then o := public.turtle_draw(); insert into public.turtle_rounds(rnd, ord, ts) values (r, o, public.now_ms()); end if;
  return o;
end $$;

-- Đặt cược
create or replace function public.rt_turtle_bet(picks int[], amount bigint) returns jsonb
language plpgsql security definer set search_path = public as $$
declare u uuid := auth.uid(); t bigint := public.now_ms(); r bigint := t / 150000; ph bigint := t - (t / 150000) * 150000;
  n int; lastt bigint; nm text; od numeric; bid bigint; ps int[];
begin
  if u is null then raise exception 'Chưa đăng nhập'; end if;
  if picks is null or array_length(picks, 1) not between 1 and 2 then return jsonb_build_object('ok', false, 'msg', 'Chọn 1 hoặc 2 con rùa.'); end if;
  select array_agg(distinct x order by x) into ps from unnest(picks) x;
  if array_length(ps, 1) <> array_length(picks, 1) or ps[1] < 0 or ps[array_length(ps, 1)] > 9 then return jsonb_build_object('ok', false, 'msg', 'Lựa chọn không hợp lệ.'); end if;
  if amount is null or amount < 100000 or amount > 20000000 then return jsonb_build_object('ok', false, 'msg', 'Mỗi lượt cược từ 100.000₫ đến 20.000.000₫.'); end if;
  if ph > 38000 then return jsonb_build_object('ok', false, 'msg', 'Đã khoá cược vòng này, chờ vòng sau.', 'wait', (150000 - ph + 500) / 1000); end if;
  perform pg_advisory_xact_lock(hashtext('turtle-u/' || u::text));
  select count(*), coalesce(max(ts), 0) into n, lastt from public.turtle_bets where uid = u and ts > t - 86400000;
  if n >= 5 then return jsonb_build_object('ok', false, 'msg', 'Bạn đã chơi đủ 5 lượt trong 24 giờ.'); end if;
  if t - lastt < 180000 then return jsonb_build_object('ok', false, 'msg', 'Hai lượt chơi phải cách nhau 3 phút.', 'wait', ceil((180000 - (t - lastt)) / 1000.0)); end if;
  select coalesce(val ->> 'name', 'Ẩn danh') into nm from public.rtdb where path = 'players/' || u::text;
  od := public.turtle_odds(ps);
  insert into public.turtle_bets(uid, name, rnd, picks, amount, odds, ts) values (u, nm, r, ps, amount, od, t) returning id into bid;
  return jsonb_build_object('ok', true, 'id', bid, 'rnd', r, 'odds', od, 'n', n + 1, 'ts', t);
end $$;

-- Lấy thứ tự về đích của vòng r (chỉ khi đã hết giờ cược)
create or replace function public.rt_turtle_round(r bigint) returns jsonb
language plpgsql security definer set search_path = public as $$
declare t bigint := public.now_ms();
begin
  if auth.uid() is null then raise exception 'Chưa đăng nhập'; end if;
  if r < t / 150000 - 4 or t < r * 150000 + 40000 then return jsonb_build_object('ok', false); end if;
  return jsonb_build_object('ok', true, 'ord', to_jsonb(public.turtle_round_ord(r)));
end $$;

-- Chốt thưởng cho các cược đã đua xong (an toàn gọi nhiều lần, mỗi cược chỉ trả 1 lần)
create or replace function public.rt_turtle_settle() returns jsonb
language plpgsql security definer set search_path = public as $$
declare u uuid := auth.uid(); t bigint := public.now_ms(); b record; o int[]; w boolean; pay bigint; tot bigint := 0; items jsonb := '[]'::jsonb;
begin
  if u is null then raise exception 'Chưa đăng nhập'; end if;
  perform pg_advisory_xact_lock(hashtext('turtle-u/' || u::text));
  for b in select * from public.turtle_bets where uid = u and not settled and t >= rnd * 150000 + 40000 + 98000 order by id loop
    o := public.turtle_round_ord(b.rnd);
    if array_length(b.picks, 1) = 1 then w := o[1] = b.picks[1]; else w := b.picks <@ array[o[1], o[2]]; end if;
    pay := case when w then floor(b.amount * b.odds) else 0 end;
    update public.turtle_bets set settled = true, win = w, payout = pay, ord = o, sts = t where id = b.id;
    tot := tot + pay;
    items := items || jsonb_build_object('id', b.id, 'rnd', b.rnd, 'amount', b.amount, 'win', w, 'payout', pay, 'picks', to_jsonb(b.picks), 'ord', to_jsonb(o));
  end loop;
  return jsonb_build_object('ok', true, 'total', tot, 'items', items);
end $$;

-- Trạng thái của tôi: số lượt 24 h, lượt gần nhất, vài cược gần đây
create or replace function public.rt_turtle_me() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare u uuid := auth.uid(); t bigint := public.now_ms();
begin
  if u is null then raise exception 'Chưa đăng nhập'; end if;
  return jsonb_build_object('now', t,
    'n24', (select count(*) from public.turtle_bets where uid = u and ts > t - 86400000),
    'last', coalesce((select max(ts) from public.turtle_bets where uid = u), 0),
    'recent', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'rnd', x.rnd, 'ts', x.ts, 'amount', x.amount, 'odds', x.odds, 'picks', to_jsonb(x.picks), 'settled', x.settled, 'win', x.win, 'payout', x.payout, 'ord', to_jsonb(x.ord)) order by x.id desc)
      from (select * from public.turtle_bets where uid = u order by id desc limit 8) x), '[]'::jsonb));
end $$;

-- Admin: lịch sử trung tâm cá cược (mới nhất trước) + tổng kết
create or replace function public.admin_turtle(lim int default 500) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Không có quyền'; end if;
  return jsonb_build_object(
    'sum', (select jsonb_build_object('bets', count(*), 'stake', coalesce(sum(amount), 0), 'paid', coalesce(sum(payout), 0), 'open', count(*) filter (where not settled), 'players', count(distinct uid)) from public.turtle_bets),
    'rows', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'uid', x.uid, 'name', x.name, 'rnd', x.rnd, 'ts', x.ts, 'amount', x.amount, 'odds', x.odds, 'picks', to_jsonb(x.picks), 'settled', x.settled, 'win', x.win, 'payout', x.payout, 'ord', to_jsonb(x.ord)) order by x.id desc)
      from (select * from public.turtle_bets order by id desc limit least(greatest(coalesce(lim, 500), 1), 3000)) x), '[]'::jsonb));
end $$;

revoke all on function public.turtle_round_ord(bigint), public.turtle_draw(), public.rt_turtle_bet(int[], bigint), public.rt_turtle_round(bigint), public.rt_turtle_settle(), public.rt_turtle_me(), public.admin_turtle(int) from public, anon;
grant execute on function public.rt_turtle_bet(int[], bigint), public.rt_turtle_round(bigint), public.rt_turtle_settle(), public.rt_turtle_me(), public.admin_turtle(int) to authenticated;
