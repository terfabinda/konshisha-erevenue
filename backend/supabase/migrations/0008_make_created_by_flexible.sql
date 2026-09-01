-- ============================================================
-- 0008_make_created_by_flexible.sql
-- Allow Firebase UIDs (non-uuid) in receipts/print_logs
-- ============================================================

-- Drop dependent policies, alter column, recreate with text comparison (auth.uid()::text)
drop policy if exists "agent read own receipts" on receipts;
drop policy if exists "agent insert receipts" on receipts;
drop policy if exists "super admin all receipts" on receipts;
drop policy if exists "printer reads own logs" on print_logs;
drop policy if exists "printer insert logs" on print_logs;

-- Drop FK constraints if they exist
do $$
begin
  if exists (select 1 from information_schema.table_constraints where constraint_name = 'receipts_created_by_fkey' and table_name = 'receipts') then
    alter table receipts drop constraint receipts_created_by_fkey;
  end if;
  if exists (select 1 from information_schema.table_constraints where constraint_name = 'receipts_voided_by_fkey' and table_name = 'receipts') then
    alter table receipts drop constraint receipts_voided_by_fkey;
  end if;
  if exists (select 1 from information_schema.table_constraints where constraint_name = 'print_logs_printed_by_fkey' and table_name = 'print_logs') then
    alter table print_logs drop constraint print_logs_printed_by_fkey;
  end if;
exception when others then null;
end $$;

-- Alter columns to text
alter table receipts alter column created_by type text using created_by::text;
alter table receipts alter column voided_by type text using voided_by::text;
alter table print_logs alter column printed_by type text using printed_by::text;

do $$
begin
  if exists (select 1 from information_schema.columns where table_name = 'login_logs' and column_name = 'user_id' and data_type = 'uuid') then
    alter table login_logs alter column user_id type text using user_id::text;
  end if;
exception when others then null;
end $$;

-- Recreate policies with text comparison
create policy "agent read own receipts" on receipts for select
  using (public.is_super_admin()
      or (public.get_user_role() = 'agent' and created_by = auth.uid()::text));

create policy "agent insert receipts" on receipts for insert
  with check (auth.uid()::text = created_by);

create policy "super admin all receipts" on receipts for all
  using (public.is_super_admin())
  with check (public.is_super_admin());

create policy "printer reads own logs" on print_logs for select
  using (public.is_super_admin()
      or (public.get_user_role() = 'agent' and printed_by = auth.uid()::text));

create policy "printer insert logs" on print_logs for insert
  with check (auth.uid()::text = printed_by);
