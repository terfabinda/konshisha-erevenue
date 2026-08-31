-- ============================================================
-- 0004_stats_functions.sql
-- Aggregation / reporting RPCs (server-side, removes client compute)
-- ============================================================

-- ---------- REVENUE STATS (date range) ----------
create or replace function public.get_revenue_stats(
  p_start timestamptz default null,
  p_end timestamptz default null
)
returns jsonb
language plpgsql stable security definer set search_path = public
as $$
declare
  v_scope text := public.current_scope_filter();
  v_start timestamptz := coalesce(p_start, now() - interval '30 days');
  v_end timestamptz := coalesce(p_end, now());
  v_total_receipts bigint;
  v_total_revenue numeric;
  v_avg numeric;
  v_top jsonb;
begin
  execute format('select count(*), coalesce(sum(total_amount),0), coalesce(avg(total_amount),0)
                  from receipts
                  where status = ''active'' and created_at >= %L and created_at <= %L and %s',
                  v_start, v_end, v_scope)
    into v_total_receipts, v_total_revenue, v_avg;

  execute format('select coalesce(jsonb_agg(x), ''[]''::jsonb) from (
                    select jsonb_build_object(
                      ''category_id'', category_id,
                      ''revenue'', rev,
                      ''count'', cnt
                    ) x from (
                      select category_id, sum(total_amount) rev, count(*) cnt
                      from receipts
                      where status = ''active'' and created_at >= %L and created_at <= %L and %s
                      group by category_id
                      order by rev desc
                      limit 5
                    ) t
                  ) sub', v_start, v_end, v_scope)
    into v_top;

  return jsonb_build_object(
    'total_receipts', v_total_receipts,
    'total_revenue', coalesce(v_total_revenue, 0),
    'avg_amount', coalesce(v_avg, 0),
    'top_categories', v_top
  );
end;
$$;

-- ---------- PRINT STATS (date range) ----------
create or replace function public.get_print_stats(
  p_start timestamptz default null,
  p_end timestamptz default null
)
returns jsonb
language plpgsql stable security definer set search_path = public
as $$
declare
  v_scope text := 'true';
  v_start timestamptz := coalesce(p_start, now() - interval '30 days');
  v_end timestamptz := coalesce(p_end, now());
  v_total bigint;
  v_success bigint;
  v_fail bigint;
  v_copies bigint;
  v_reprint bigint;
begin
  if public.is_scoped_admin() then
    v_scope := format('agency_id = %L::uuid', public.get_agency_id());
  elsif not public.is_super_admin() then
    v_scope := format('printed_by = %L::uuid', auth.uid());
  end if;

  execute format('select count(*),
                         count(*) filter (where success),
                         count(*) filter (where not success),
                         coalesce(sum(copies),0),
                         count(*) filter (where is_reprint)
                  from print_logs
                  where printed_at >= %L and printed_at <= %L and %s',
                  v_start, v_end, v_scope)
    into v_total, v_success, v_fail, v_copies, v_reprint;

  return jsonb_build_object(
    'total_prints', v_total,
    'success_count', coalesce(v_success, 0),
    'fail_count', coalesce(v_fail, 0),
    'total_copies', coalesce(v_copies, 0),
    'reprint_count', coalesce(v_reprint, 0),
    'success_rate', case when v_total > 0 then round((v_success::numeric / v_total) * 100, 2) else 0 end
  );
end;
$$;

-- ---------- REVENUE TREND (daily buckets for charts) ----------
create or replace function public.get_revenue_trend(
  p_days int default 30
)
returns jsonb
language plpgsql stable security definer set search_path = public
as $$
declare
  v_scope text := public.current_scope_filter();
  v_out jsonb;
begin
  execute format('select coalesce(jsonb_agg(x), ''[]''::jsonb) from (
                    select jsonb_build_object(
                      ''day'', to_char(d, ''YYYY-MM-DD''),
                      ''revenue'', coalesce(sum(r.total_amount), 0),
                      ''count'', count(r.id)
                    ) x from generate_series(
                      date_trunc(''day'', now() - (%L::int || '' days'')::interval),
                      date_trunc(''day'', now()),
                      ''1 day''::interval
                    ) d
                    left join receipts r
                      on date_trunc(''day'', r.created_at) = d
                     and r.status = ''active''
                     and %s
                    group by d
                    order by d
                  ) sub', p_days, v_scope)
    into v_out;
  return v_out;
end;
$$;

-- ---------- AGENCY SUMMARY (super admin) ----------
create or replace function public.get_agency_summary()
returns jsonb
language plpgsql stable security definer set search_path = public
as $$
begin
  if not public.is_super_admin() then
    raise exception 'not authorized';
  end if;
  return (
    select coalesce(jsonb_agg(x), '[]'::jsonb) from (
      select jsonb_build_object(
        'agency_id', a.id,
        'agency_name', a.name,
        'code', a.code,
        'total_revenue', coalesce(sum(r.total_amount) filter (where r.status = 'active'), 0),
        'total_receipts', count(r.id) filter (where r.status = 'active'),
        'total_agents', (select count(*) from profiles p where p.agency_id = a.id and p.role = 'agent')
      ) x
      from agencies a
      left join receipts r on r.agency_id = a.id
      group by a.id
      order by a.name
    ) sub
  );
end;
$$;

-- ---------- AGENT SUMMARY (admin) ----------
create or replace function public.get_agent_summary()
returns jsonb
language plpgsql stable security definer set search_path = public
as $$
declare
  v_scope text := 'true';
  v_out jsonb;
begin
  if public.is_scoped_admin() then
    v_scope := format('agency_id = %L::uuid', public.get_agency_id());
  elsif not (public.is_super_admin() or public.get_user_role() = 'admin') then
    raise exception 'not authorized';
  end if;

  execute format(
    'select coalesce(jsonb_agg(x), ''[]''::jsonb) from (
       select jsonb_build_object(
         ''user_id'', p.id,
         ''display_name'', p.display_name,
         ''email'', p.username,
         ''total_receipts'', count(r.id) filter (where r.status = ''active''),
         ''total_revenue'', coalesce(sum(r.total_amount) filter (where r.status = ''active''), 0),
         ''total_prints'', (select count(*) from print_logs pl where pl.printed_by = p.id)
       ) x
       from profiles p
       left join receipts r on r.created_by = p.id
       where p.role = ''agent'' and %s
       group by p.id
     ) sub',
    v_scope
  ) into v_out;

  return v_out;
end;
$$;

-- ============================================================
-- AGENT & AGENCY COUNTS for lists
-- ============================================================
create or replace function public.get_agency_agent_count(p_agency_id uuid)
returns bigint
language sql stable security definer set search_path = public
as $$
  select count(*) from profiles where agency_id = p_agency_id and role = 'agent';
$$;

create or replace function public.get_agency_receipt_count(p_agency_id uuid)
returns bigint
language sql stable security definer set search_path = public
as $$
  select count(*) from receipts where agency_id = p_agency_id;
$$;

create or replace function public.get_agent_receipt_count(p_user_id uuid)
returns bigint
language sql stable security definer set search_path = public
as $$
  select count(*) from receipts where created_by = p_user_id;
$$;

create or replace function public.get_agent_print_count(p_user_id uuid)
returns bigint
language sql stable security definer set search_path = public
as $$
  select count(*) from print_logs where printed_by = p_user_id;
$$;

-- ============================================================
-- BIND DEVICE + verification helpers
-- ============================================================
create or replace function public.bind_device(p_fingerprint text)
returns void
language plpgsql volatile security definer set search_path = public
as $$
begin
  update profiles
     set bound_device_fingerprint = p_fingerprint,
         device_fingerprint_fixed = true
   where id = auth.uid();
end;
$$;

create or replace function public.verify_device(p_fingerprint text)
returns boolean
language sql stable security definer set search_path = public
as $$
  select bound_device_fingerprint = p_fingerprint
    from profiles
   where id = auth.uid();
$$;
