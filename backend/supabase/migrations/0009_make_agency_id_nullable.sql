-- 0009_make_agency_id_nullable.sql
-- Allow Firebase-UID style agency_id to sync as null (was uuid NOT NULL)
-- The sync_receipts RPC now guards non-UUID values via ~ '^[0-9a-f-]{36}$' and the
-- column must be nullable so offline Firebase-origin receipts don't violate NOT NULL.
alter table receipts alter column agency_id drop not null;
