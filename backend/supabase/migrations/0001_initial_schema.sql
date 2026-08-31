-- ============================================================
-- 0001_initial_schema.sql
-- Konshisha IGR: initial tables + RLS policies
-- Run via: supabase db push  (or apply to remote)
-- ============================================================

-- ---------- EXTENSIONS ----------
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- ---------- ENUMS ----------
create type user_role as enum ('admin', 'agent');
create type receipt_status as enum ('active', 'voided');
create type print_mode as enum ('text', 'image');

-- ---------- AGENCIES ----------
create table agencies (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  code text not null unique,
  address text,
  phone text,
  email text,
  tin text,
  admin_name text,
  admin_phone text,
  receipt_prefix int not null default 1000,
  next_receipt_number int not null default 1,
  custom_settings jsonb,
  is_active boolean not null default true,
  onboarded_by uuid references auth.users(id),
  onboarded_at timestamptz,
  created_at timestamptz not null default now()
);

create index idx_agencies_is_active on agencies(is_active);

-- ---------- PROFILES (extends auth.users) ----------
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text,
  display_name text,
  role user_role not null default 'agent',
  agency_id uuid references agencies(id) on delete set null,
  bound_device_fingerprint text,
  device_fingerprint_fixed boolean not null default false,
  max_offline_days int not null default 7,
  expiry_days int,
  login_expiry_at timestamptz,
  last_login_at timestamptz,
  is_active boolean not null default true,
  must_change_password boolean not null default false,
  created_at timestamptz not null default now(),
  -- merchant profile fields
  first_name text,
  last_name text,
  phone text,
  tin text,
  shop_name text,
  location text
);

create index idx_profiles_agency on profiles(agency_id);
create index idx_profiles_role on profiles(role);

-- ---------- REVENUE CATEGORIES ----------
create table categories (
  id uuid primary key default uuid_generate_v4(),
  name text not null unique,
  default_amount numeric(14,2),
  is_enabled boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

-- per-agency category override
create table agency_categories (
  agency_id uuid not null references agencies(id) on delete cascade,
  category_id uuid not null references categories(id) on delete cascade,
  enabled boolean not null default true,
  default_amount numeric(14,2),
  primary key (agency_id, category_id)
);

-- ---------- RECEIPTS ----------
create table receipts (
  id text primary key, -- client-generated id (RCP-<millis>) — idempotent by design
  agency_id uuid not null references agencies(id),
  created_by uuid not null references auth.users(id),
  payer_name text not null,
  payer_phone text,
  payer_tin text,
  payer_address text,
  category_id uuid references categories(id),
  category_name text, -- denormalized in case category is removed
  description text,
  amount numeric(14,2) not null default 0,
  discount numeric(14,2) default 0,
  penalty numeric(14,2) default 0,
  total_amount numeric(14,2) not null default 0,
  quantity int not null default 1,
  status receipt_status not null default 'active',
  voided_by uuid references auth.users(id),
  voided_at timestamptz,
  notes text,
  device_fingerprint text,
  receipt_ref text, -- server-assigned sequential ref
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

create index idx_receipts_agency on receipts(agency_id);
create index idx_receipts_created_by on receipts(created_by);
create index idx_receipts_created_at on receipts(created_at);
create index idx_receipts_status on receipts(status);
create index idx_receipts_category on receipts(category_id);

-- ---------- PRINT LOGS ----------
create table print_logs (
  id text primary key, -- client-generated id (PRINT-<millis>)
  receipt_id text references receipts(id) on delete set null,
  receipt_ref text,
  printed_at timestamptz not null default now(),
  copies int not null default 1,
  print_mode print_mode not null default 'text',
  printer_name text,
  printer_address text,
  printer_model text,
  success boolean not null default true,
  error_message text,
  printed_by uuid not null references auth.users(id),
  agency_id uuid references agencies(id) on delete set null,
  is_reprint boolean not null default false
);

create index idx_prints_receipt on print_logs(receipt_id);
create index idx_prints_printed_by on print_logs(printed_by);
create index idx_prints_printed_at on print_logs(printed_at);
create index idx_prints_agency on print_logs(agency_id);
create index idx_prints_success on print_logs(success);

-- ---------- SECURITY CONFIG (single row) ----------
create table security_config (
  id int primary key default 1 check (id = 1),
  max_offline_days int not null default 7,
  login_expiry_days int not null default 30,
  min_version_code int not null default 1,
  force_sync boolean not null default false,
  security_alerts text[] not null default '{}',
  updated_at timestamptz not null default now()
);

insert into security_config (id) values (1) on conflict do nothing;

-- ---------- SECURITY COMMANDS ----------
create table security_commands (
  id uuid primary key default uuid_generate_v4(),
  type text not null, -- 'force_sync'
  target text,        -- 'global' | user id
  issued_by uuid references auth.users(id),
  issued_at timestamptz not null default now()
);

-- ---------- NOTIFICATIONS (future) ----------
create table notifications (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  body text,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

-- ---------- BILLS / PAYERS (future) ----------
create table payers (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  phone text,
  tin text unique,
  address text,
  agency_id uuid references agencies(id) on delete set null,
  created_at timestamptz not null default now()
);

create table bills (
  id uuid primary key default uuid_generate_v4(),
  payer_id uuid references payers(id) on delete cascade,
  agency_id uuid references agencies(id),
  category_id uuid references categories(id),
  amount numeric(14,2) not null,
  status text not null default 'outstanding', -- outstanding | paid | voided
  receipt_id text references receipts(id) on delete set null,
  due_at timestamptz,
  created_at timestamptz not null default now()
);
