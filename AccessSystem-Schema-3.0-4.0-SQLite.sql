-- Convert schema './AccessSystem-Schema-3.0-SQLite.sql' to './AccessSystem-Schema-4.0-SQLite.sql':;

BEGIN;

CREATE TABLE "membership_register" (
  "name" varchar(255) NOT NULL,
  "address" varchar(1024) NOT NULL,
  "started_date" datetime NOT NULL,
  "ended_date" datetime,
  "updated_date" datetime,
  "updated_reason" varchar(1024) NOT NULL,
  PRIMARY KEY ("name", "started_date")
);

ALTER TABLE "people" ADD COLUMN "analytics_use" boolean NOT NULL DEFAULT 0;

DROP INDEX ;



COMMIT;


