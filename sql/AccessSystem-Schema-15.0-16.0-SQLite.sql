-- Convert schema 'sql/AccessSystem-Schema-15.0-SQLite.sql' to 'sql/AccessSystem-Schema-16.0-SQLite.sql':;

BEGIN;

ALTER TABLE "usage_log" ADD COLUMN "running_for" integer NOT NULL DEFAULT 0;


COMMIT;


