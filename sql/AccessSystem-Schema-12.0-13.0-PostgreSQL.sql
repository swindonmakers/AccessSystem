-- Convert schema 'sql/AccessSystem-Schema-12.0-PostgreSQL.sql' to 'sql/AccessSystem-Schema-13.0-PostgreSQL.sql':;

BEGIN;

ALTER TABLE tiers DROP CONSTRAINT ;

ALTER TABLE tiers DROP COLUMN dont_use;

ALTER TABLE tiers ADD COLUMN in_use boolean DEFAULT '1' NOT NULL;


COMMIT;


