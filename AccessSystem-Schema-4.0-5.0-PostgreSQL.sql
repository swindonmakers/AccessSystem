-- Convert schema './AccessSystem-Schema-4.0-PostgreSQL.sql' to './AccessSystem-Schema-5.0-PostgreSQL.sql':;

BEGIN;

ALTER TABLE people DROP CONSTRAINT ;

ALTER TABLE people DROP COLUMN analytics_use;

ALTER TABLE people ADD COLUMN google_id character varying(255);


COMMIT;


