-- Convert schema './AccessSystem-Schema-10.0-PostgreSQL.sql' to './AccessSystem-Schema-11.0-PostgreSQL.sql':;

BEGIN;

ALTER TABLE allowed ADD COLUMN accepted_on timestamp;


COMMIT;


