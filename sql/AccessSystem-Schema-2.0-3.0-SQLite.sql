-- Convert schema './AccessSystem-Schema-2.0-SQLite.sql' to './AccessSystem-Schema-3.0-SQLite.sql':;

BEGIN;

DROP INDEX ;


ALTER TABLE "people" ADD COLUMN "payment_override" float;


COMMIT;


