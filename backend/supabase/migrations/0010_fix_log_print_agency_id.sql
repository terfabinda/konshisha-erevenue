-- 0010_fix_log_print_agency_id.sql
-- Allow Firebase-UID style agency_id and handle service_role printed_by (was uuid, auth.uid() null)
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
  p_agency_id text default null
)
returns print_logs language plpgsql volatile security definer set search_path=public as $$
declare v_log print_logs; v_agency uuid; v_printed_by text; begin
  select * into v_log from print_logs where id=p_id;
  if v_log is not null then return v_log; end if;
  v_agency := case when p_agency_id ~ '^[0-9a-f-]{36}$' then p_agency_id::uuid else null end;
  v_printed_by := coalesce(auth.uid()::text, 'unknown');
  insert into print_logs (id, receipt_id, receipt_ref, copies, print_mode, printer_name, printer_address, printer_model, success, error_message, printed_by, agency_id, is_reprint)
  values (p_id, p_receipt_id, p_receipt_ref, p_copies, p_print_mode, p_printer_name, p_printer_address, p_printer_model, p_success, p_error_message, v_printed_by, v_agency, p_is_reprint) returning * into v_log;
  return v_log;
end; $$;
