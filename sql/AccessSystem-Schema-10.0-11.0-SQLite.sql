-- Convert schema './AccessSystem-Schema-10.0-SQLite.sql' to './AccessSystem-Schema-11.0-SQLite.sql':;

BEGIN;

ALTER TABLE "allowed" ADD COLUMN "accepted_on" datetime;


COMMIT;


