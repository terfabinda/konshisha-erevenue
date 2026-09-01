-- ============================================================
-- 0007_login_logs_device_info.sql
-- Add device/platform columns for richer login audit
-- ============================================================

alter table login_logs
  add column if not exists platform text,
  add column if not exists device_name text,
  add column if not exists os_version text;

create index if not exists idx_login_logs_platform on login_logs(platform);
