-- ============================================================
-- 0005_fix_dashboard_and_grants.sql
-- Fix get_dashboard_stats (jsonb_agg order bug + v_out overwrite)
-- and grant EXECUTE to authenticated/anon for all public RPCs.
-- ============================================================

-- ---------- FIXED DASHBOARD STATS ----------
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
  v_totals jsonb;
begin
  execute format('select coalesce(sum(total_amount),0), count(*) from receipts
                  where status = ''active'' and created_at >= %L and %s', v_today, v_scope)
    into v_today_revenue, v_today_count;

  execute format('select coalesce(jsonb_agg(x), ''[]''::jsonb) from (
                    select jsonb_build_object(
                      ''id'', id, ''payer_name'', payer_name,
                      ''category_id'', category_id, ''description'', description,
                      ''amount'', amount, ''total_amount'', total_amount,
                      ''created_at'', created_at, ''status'', status,
                      ''receipt_ref'', receipt_ref, ''agency_id'', agency_id
                    ) x from receipts where %s order by created_at desc limit 5
                  ) sub', v_scope)
    into v_recent;

  v_out := jsonb_build_object(
    'today_revenue', coalesce(v_today_revenue, 0),
    'today_receipt_count', coalesce(v_today_count, 0),
    'recent_receipts', coalesce(v_recent, '[]'::jsonb)
  );

  v_totals := jsonb_build_object(
    'total_agencies', (select count(*) from agencies),
    'total_agents', (select count(*) from profiles where role = 'agent'),
    'total_revenue', (select coalesce(sum(total_amount),0) from receipts where status = 'active'),
    'total_receipts', (select count(*) from receipts where status = 'active')
  );

  v_out := v_out || v_totals;

  if not public.is_super_admin() then
    v_out := v_out - '{total_agencies,total_agents}'::text[];
  end if;

  return v_out;
end;
$$;

-- ---------- GRANTS ----------
grant execute on function public.get_dashboard_stats() to anon, authenticated, service_role;
grant execute on function public.get_revenue_stats(timestamptz, timestamptz) to anon, authenticated, service_role;
grant execute on function public.get_print_stats(timestamptz, timestamptz) to anon, authenticated, service_role;
grant execute on function public.get_revenue_trend(int) to anon, authenticated, service_role;
grant execute on function public.get_agency_summary() to anon, authenticated, service_role;
grant execute on function public.get_agent_summary() to anon, authenticated, service_role;
grant execute on function public.get_agency_agent_count(uuid) to anon, authenticated, service_role;
grant execute on function public.get_agency_receipt_count(uuid) to anon, authenticated, service_role;
grant execute on function public.get_agent_receipt_count(uuid) to anon, authenticated, service_role;
grant execute on function public.get_agent_print_count(uuid) to anon, authenticated, service_role;
grant execute on function public.current_scope_filter() to anon, authenticated, service_role;
grant execute on function public.is_super_admin() to anon, authenticated, service_role;
grant execute on function public.is_scoped_admin() to anon, authenticated, service_role;
grant execute on function public.get_user_role() to anon, authenticated, service_role;
grant execute on function public.get_agency_id() to anon, authenticated, service_role;
grant execute on function public.upsert_receipt(text, uuid, text, text, text, text, uuid, text, text, numeric, numeric, numeric, int, text, text, receipt_status) to anon, authenticated, service_role;
grant execute on function public.sync_receipts(jsonb) to anon, authenticated, service_role;
grant execute on function public.void_receipt(text) to anon, authenticated, service_role;
grant execute on function public.issue_receipt_ref(uuid) to anon, authenticated, service_role;
grant execute on function public.log_print(text, text, int, print_mode, text, text, text, boolean, text, boolean, text, uuid) to anon, authenticated, service_role;
grant execute on function public.update_print_log(text, boolean, text, int) to anon, authenticated, service_role;
grant execute on function public.bind_device(text) to anon, authenticated, service_role;
grant execute on function public.verify_device(text) to anon, authenticated, service_role;
