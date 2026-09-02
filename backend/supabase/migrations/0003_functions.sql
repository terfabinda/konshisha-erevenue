-- ============================================================
-- 0003_functions.sql
-- RPC functions supporting the offline-first, idempotent model.
-- Called by the Node.js API via PostgREST /rpc/<fn>
-- ============================================================

-- ---------- TENANT SCOPING HELPER ----------
-- Returns the SQL filter string used by aggregate RPCs to respect
-- agent / scoped-admin / super-admin scoping without injecting params.
create or replace function public.current_scope_filter()
returns text
language plpgsql stable security definer set search_path = public
as $$
begin
  if public.is_super_admin() then
    return 'true';
  elsif public.is_scoped_admin() then
    return format('agency_id = %L::uuid', public.get_agency_id());
  else
    return format('created_by = %L::text', auth.uid());
  end if;
end;
$$;

-- ============================================================
-- UPSERT RECEIPT (idempotent) — core offline-safe create
-- ============================================================
create or replace function public.upsert_receipt(
  p_id text,
  p_agency_id uuid,
  p_payer_name text,
  p_payer_phone text default null,
  p_payer_tin text default null,
  p_payer_address text default null,
  p_category_id uuid default null,
  p_category_name text default null,
  p_description text default null,
  p_amount numeric default 0,
  p_discount numeric default 0,
  p_penalty numeric default 0,
  p_quantity int default 1,
  p_notes text default null,
  p_device_fingerprint text default null,
  p_status receipt_status default 'active'
)
returns receipts
language plpgsql volatile security definer set search_path = public
as $$
declare
  v_total numeric;
  v_row receipts;
begin
  -- idempotency: if the client-generated id already exists, return it untouched
  select * into v_row from receipts where id = p_id;
  if v_row is not null then
    return v_row;
  end if;

  v_total := coalesce(p_amount, 0) + coalesce(p_penalty, 0) - coalesce(p_discount, 0);

  insert into receipts (
    id, agency_id, created_by, payer_name, payer_phone, payer_tin,
    payer_address, category_id, category_name, description, amount,
    discount, penalty, total_amount, quantity, notes, device_fingerprint, status
  )
  values (
    p_id, p_agency_id, auth.uid(), p_payer_name, p_payer_phone, p_payer_tin,
    p_payer_address, p_category_id, coalesce(p_category_name, ''),
    coalesce(p_description, p_payer_name), p_amount, p_discount, p_penalty,
    v_total, p_quantity, p_notes, p_device_fingerprint, p_status
  )
  returning * into v_row;

  return v_row;
end;
$$;

-- ============================================================
-- SYNC RECEIPTS — bulk idempotent uplink from offline queue
-- ============================================================
create or replace function public.sync_receipts(
  p_rows jsonb
)
returns table(synced_id text, created boolean)
language plpgsql volatile security definer set search_path = public
as $$
declare
  r jsonb;
  v_row receipts;
  v_total numeric;
  v_created_by text;
begin
  for r in select * from jsonb_array_elements(p_rows) loop
    if not exists (select 1 from receipts where id = r->>'id') then
      v_total := coalesce((r->>'amount')::numeric, 0)
               + coalesce((r->>'penalty')::numeric, 0)
               - coalesce((r->>'discount')::numeric, 0);
      v_created_by := coalesce(auth.uid()::text, r->>'created_by', r->>'createdBy', r->>'created_by_text', 'unknown');

insert into receipts (
        id, agency_id, created_by, payer_name, payer_phone, payer_tin,
        payer_address, category_id, category_name, description, amount,
        discount, penalty, total_amount, quantity, notes, device_fingerprint, status
      )
      values (
        r->>'id',
        case when (r->>'agency_id') ~ '^[0-9a-f-]{36}$' then (r->>'agency_id')::uuid else null end,
        v_created_by,
        coalesce(r->>'payer_name', ''),
        r->>'payer_phone', r->>'payer_tin', r->>'payer_address',
        case when (r->>'category_id') ~ '^[0-9a-f-]{36}$' then (r->>'category_id')::uuid else null end,
        coalesce(r->>'category_name',''),
        r->>'description',
        coalesce((r->>'amount')::numeric, 0),
        coalesce((r->>'discount')::numeric, 0),
        coalesce((r->>'penalty')::numeric, 0),
        v_total,
        coalesce((r->>'quantity')::int, 1),
        r->>'notes', r->>'device_fingerprint',
        coalesce((r->>'status')::receipt_status, 'active')
      );
      synced_id := r->>'id';
      created := true;
      return next;
    else
      synced_id := r->>'id';
      created := false;
      return next;
    end if;
  end loop;
  return;
end;
$$;

-- ============================================================
-- VOID RECEIPT
-- ============================================================
create or replace function public.void_receipt(p_receipt_id text)
returns receipts
language plpgsql volatile security definer set search_path = public
as $$
declare
  v_row receipts;
begin
  update receipts
     set status = 'voided',
         voided_by = auth.uid(),
         voided_at = now(),
         updated_at = now()
   where id = p_receipt_id
     and (created_by = auth.uid()
          or (public.get_user_role() = 'admin' and agency_id = public.get_agency_id())
          or public.is_super_admin())
  returning * into v_row;

  if v_row is null then
    raise exception 'receipt not found or not permitted';
  end if;
  return v_row;
end;
$$;

-- ============================================================
-- ISSUE / GENERATE NEXT SEQUENTIAL RECEIPT REF
-- ============================================================
create or replace function public.issue_receipt_ref(p_agency_id uuid)
returns text
language plpgsql volatile security definer set search_path = public
as $$
declare
  v_agency agencies%rowtype;
  v_ref text;
begin
  select * into v_agency from agencies where id = p_agency_id for update;
  if v_agency is null then
    raise exception 'agency not found';
  end if;

  v_ref := v_agency.receipt_prefix::text || lpad(v_agency.next_receipt_number::text, 6, '0');
  update agencies set next_receipt_number = next_receipt_number + 1 where id = p_agency_id;
  return v_ref;
end;
$$;

-- ============================================================
-- LOG PRINT (idempotent by client id)
-- ============================================================
create or replace function public.log_print(
  p_id text,
  p_receipt_id text,
  p_copies int default 1,
  p_print_mode print_mode default 'text',
  p_printer_name text default null,
  p_printer_address text default null,
  p_printer_model text default null,
  p_success boolean default true,
  p_error_message text default null,
  p_is_reprint boolean default false,
  p_receipt_ref text default null,
  p_agency_id uuid default null
)
returns print_logs
language plpgsql volatile security definer set search_path = public
as $$
declare
  v_log print_logs;
begin
  select * into v_log from print_logs where id = p_id;
  if v_log is not null then
    return v_log;
  end if;

  insert into print_logs (
    id, receipt_id, receipt_ref, copies, print_mode, printer_name,
    printer_address, printer_model, success, error_message, printed_by,
    agency_id, is_reprint
  ) values (
    p_id, p_receipt_id, p_receipt_ref, p_copies, p_print_mode, p_printer_name,
    p_printer_address, p_printer_model, p_success, p_error_message, auth.uid(),
    p_agency_id, p_is_reprint
  ) returning * into v_log;

  return v_log;
end;
$$;

-- ============================================================
-- UPDATE PRINT RESULT (after async print completes)
-- ============================================================
create or replace function public.update_print_log(
  p_id text,
  p_success boolean,
  p_error_message text default null,
  p_copies int default null
)
returns print_logs
language plpgsql volatile security definer set search_path = public
as $$
declare
  v_log print_logs;
begin
  update print_logs
     set success = p_success,
         error_message = coalesce(p_error_message, error_message),
         copies = coalesce(p_copies, copies)
   where id = p_id
  returning * into v_log;
  return v_log;
end;
$$;

-- ============================================================
-- DASHBOARD STATS
-- ============================================================
create or replace function public.get_dashboard_stats()
returns jsonb
language plpgsql stable security definer set search_path = public
as $$
declare
  v_scope text := public.current_scope_filter();
  v_today timestamptz := date_trunc('day', now());
  v_today_revenue numeric;
  v_today_count bigint;
  v_recent jsonb;
  v_out jsonb;
begin
  execute format('select coalesce(sum(total_amount),0), count(*) from receipts
                  where status = ''active'' and created_at >= %L and %s', v_today, v_scope)
    into v_today_revenue, v_today_count;

  execute format('select coalesce(jsonb_agg(x order by created_at desc), ''[]''::jsonb) from (
                    select jsonb_build_object(
                      ''id'', id, ''payer_name'', payer_name,
                      ''category_id'', category_id, ''description'', description,
                      ''amount'', amount, ''total_amount'', total_amount,
                      ''created_at'', created_at, ''status'', status
                    ) x from receipts where %s order by created_at desc limit 5
                  ) sub', v_scope)
    into v_recent;

  v_out := jsonb_build_object(
    'today_revenue', coalesce(v_today_revenue, 0),
    'today_receipt_count', coalesce(v_today_count, 0),
    'recent_receipts', v_recent
  );

  select jsonb_build_object(
    'total_agencies', (select count(*) from agencies),
    'total_agents', (select count(*) from profiles where role = 'agent'),
    'total_revenue', (select coalesce(sum(total_amount),0) from receipts where status = 'active'),
    'total_receipts', (select count(*) from receipts where status = 'active')
  ) into v_out;

  -- merge superset; for non-super-admin we only expose the scoped totals
  if not public.is_super_admin() then
    v_out := v_out - '{total_agencies,total_agents}'::text[];
  end if;

  return v_out;
end;
$$;
