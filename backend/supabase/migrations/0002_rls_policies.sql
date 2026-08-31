-- ============================================================
-- 0002_rls_policies.sql
-- Row Level Security policies mirroring the app's scoping rules:
--   agent         -> own data (created_by / printed_by = auth.uid())
--   scoped_admin  -> own agency only
--   super_admin   -> full access (admin with agency_id IS NULL)
-- ============================================================

-- ---------- helper: current user's role / agency ----------
-- NOTE: these MUST live in the `public` schema (creating in `auth` is
-- restricted to Supabase internal roles). They are security-definer so
-- the caller's own RLS limits do not affect the lookups below.
create or replace function public.get_user_role() returns user_role
language sql stable security definer set search_path = public
as $$
  select (coalesce(
    (select role from profiles where id = auth.uid()),
    (auth.jwt() -> 'app_metadata' ->> 'role')::user_role,
    'agent'
  ))
$$;

create or replace function public.get_agency_id() returns uuid
language sql stable security definer set search_path = public
as $$
  select agency_id from profiles where id = auth.uid()
$$;

create or replace function public.is_super_admin() returns boolean
language sql stable security definer set search_path = public
as $$
  select public.get_user_role() = 'admin' and public.get_agency_id() is null
$$;

create or replace function public.is_scoped_admin() returns boolean
language sql stable security definer set search_path = public
as $$
  select public.get_user_role() = 'admin' and public.get_agency_id() is not null
$$;

-- ============================================================
-- enable RLS on all tables
-- ============================================================
alter table agencies enable row level security;
alter table profiles enable row level security;
alter table categories enable row level security;
alter table agency_categories enable row level security;
alter table receipts enable row level security;
alter table print_logs enable row level security;
alter table security_config enable row level security;
alter table security_commands enable row level security;
alter table notifications enable row level security;
alter table payers enable row level security;
alter table bills enable row level security;

-- ============================================================
-- PROFILES
-- users can read/update their own; admins can manage profiles in scope
-- ============================================================
create policy "own profile select" on profiles for select
  using (id = auth.uid() or public.is_super_admin());

create policy "own profile insert" on profiles for insert
  with check (id = auth.uid() or public.is_super_admin());

create policy "own profile update" on profiles for update
  using (id = auth.uid() or public.is_super_admin());

create policy "scoped admin select agency profiles" on profiles for select
  using (public.is_scoped_admin() and agency_id = public.get_agency_id());

create policy "scoped admin update agency profiles" on profiles for update
  using (public.is_scoped_admin() and agency_id = public.get_agency_id());

-- ============================================================
-- AGENCIES
-- agents see active agencies; admins see all active + manage
-- ============================================================
create policy "agent read active agencies" on agencies for select
  using (is_active = true);

create policy "admin read agencies" on agencies for select
  using (public.get_user_role() = 'admin');

create policy "scoped admin update own agency" on agencies for update
  using (public.is_scoped_admin() and id = public.get_agency_id());

create policy "super admin write agencies" on agencies for all
  using (public.is_super_admin())
  with check (public.is_super_admin());

-- ============================================================
-- RECEIPTS
-- ============================================================
create policy "agent read own receipts" on receipts for select
  using (public.is_super_admin()
      or (public.is_scoped_admin() and agency_id = public.get_agency_id())
      or (public.get_user_role() = 'agent' and created_by = auth.uid()));

create policy "agent insert receipts" on receipts for insert
  with check (auth.uid() = created_by);

create policy "super admin all receipts" on receipts for all
  using (public.is_super_admin())
  with check (public.is_super_admin());

-- objects updated via security-definer RPC void_receipt, so no direct
-- update policy needed for now. Grant selective update below if required.

-- ============================================================
-- PRINT LOGS
-- ============================================================
create policy "printer reads own logs" on print_logs for select
  using (public.is_super_admin()
      or (public.is_scoped_admin() and agency_id = public.get_agency_id())
      or (public.get_user_role() = 'agent' and printed_by = auth.uid()));

create policy "printer insert logs" on print_logs for insert
  with check (auth.uid() = printed_by);

-- ============================================================
-- CATEGORIES & AGENCY CATEGORIES
-- ============================================================
create policy "categories readable" on categories for select using (true);
create policy "super admin manage categories" on categories for all
  using (public.is_super_admin()) with check (public.is_super_admin());

create policy "agency categories readable" on agency_categories for select using (true);
create policy "admin manage own agency categories" on agency_categories for all
  using (public.is_scoped_admin() and agency_id = public.get_agency_id()
     or public.is_super_admin())
  with check (true);

-- ============================================================
-- SECURITY CONFIG
-- ============================================================
create policy "security readable" on security_config for select using (true);
create policy "admin manage security" on security_config for all
  using (public.is_super_admin()) with check (public.is_super_admin());

create policy "security commands readable" on security_commands for select using (true);
create policy "super admin issue commands" on security_commands for insert
  with check (public.is_super_admin());

-- ============================================================
-- NOTIFICATIONS / PAYERS / BILLS (future)
-- ============================================================
create policy "own notifications" on notifications for all
  using (user_id = auth.uid() or public.is_super_admin())
  with check (user_id = auth.uid() or public.is_super_admin());

create policy "payers readable scoped" on payers for select using (true);
create policy "admins manage payers" on payers for all
  using (public.get_user_role() = 'admin') with check (public.get_user_role() = 'admin');

create policy "bills readable" on bills for select using (true);
create policy "admins manage bills" on bills for all
  using (public.get_user_role() = 'admin') with check (public.get_user_role() = 'admin');
