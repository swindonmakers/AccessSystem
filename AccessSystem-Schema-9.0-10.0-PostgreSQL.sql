-- Convert schema './AccessSystem-Schema-9.0-PostgreSQL.sql' to './AccessSystem-Schema-10.0-PostgreSQL.sql':;

BEGIN;

ALTER TABLE allowed ADD COLUMN pending_acceptance boolean DEFAULT 'true' NOT NULL;


COMMIT;


