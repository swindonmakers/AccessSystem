-- Convert schema 'sql/AccessSystem-Schema-15.0-PostgreSQL.sql' to 'sql/AccessSystem-Schema-16.0-PostgreSQL.sql':;

BEGIN;

ALTER TABLE usage_log ADD COLUMN running_for integer DEFAULT 0 NOT NULL;


COMMIT;


