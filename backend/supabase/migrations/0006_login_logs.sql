-- ============================================================
-- 0006_login_logs.sql
-- Agent / admin login activity audit
-- ============================================================

create table login_logs (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references auth.users(id) on delete set null,
  email text,
  display_name text,
  agency_id uuid references agencies(id) on delete set null,
  agency_code text,
  agency_name text,
  login_at timestamptz not null default now(),
  ip_address text,
  user_agent text,
  device_fingerprint text,
  success boolean not null default true,
  failure_reason text
);

create index idx_login_logs_user on login_logs(user_id);
create index idx_login_logs_agency on login_logs(agency_id);
create index idx_login_logs_at on login_logs(login_at desc);
create index idx_login_logs_success on login_logs(success);

alter table login_logs enable row level security;

-- Super admin sees all; scoped admin sees own agency; agent sees own
create policy "super admin all login_logs" on login_logs for all
  using (public.is_super_admin())
  with check (public.is_super_admin());

create policy "scoped admin agency login_logs" on login_logs for select
  using (
    public.is_scoped_admin()
    and agency_id = public.get_agency_id()
  );

create policy "agent own login_logs" on login_logs for select
  using (user_id = auth.uid());

-- Allow authenticated to insert their own login event (client-side logging)
create policy "authenticated insert login_logs" on login_logs for insert
  with check (auth.role() = 'authenticated');

grant select, insert on login_logs to authenticated;
grant select on login_logs to anon;
