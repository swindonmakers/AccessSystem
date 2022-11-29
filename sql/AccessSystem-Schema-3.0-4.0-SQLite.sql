-- Convert schema './AccessSystem-Schema-3.0-SQLite.sql' to './AccessSystem-Schema-4.0-SQLite.sql':;

BEGIN;

CREATE TABLE "membership_register" (
  "name" varchar(255) NOT NULL,
  "address" varchar(1024) NOT NULL,
  "started_date" date NOT NULL,
  "ended_date" date,
  "updated_date" datetime,
  "updated_reason" varchar(1024) NOT NULL,
  PRIMARY KEY ("name", "started_date")
);

ALTER TABLE "allowed" ADD COLUMN "added_on" datetime NOT NULL DEFAULT '2016-03-01';

CREATE TEMPORARY TABLE "people_temp_alter" (
  "id" INTEGER PRIMARY KEY NOT NULL,
  "parent_id" integer,
  "name" varchar(255) NOT NULL,
  "email" varchar(255),
  "opt_in" boolean NOT NULL DEFAULT 0,
  "analytics_use" boolean NOT NULL DEFAULT 0,
  "dob" varchar(7) NOT NULL,
  "address" varchar(1024) NOT NULL,
  "github_user" varchar(255),
  "concessionary_rate_override" varchar(255) DEFAULT '',
  "payment_override" float,
  "member_of_other_hackspace" boolean NOT NULL DEFAULT 0,
  "created_date" datetime NOT NULL,
  "end_date" datetime,
  FOREIGN KEY ("parent_id") REFERENCES "people"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

INSERT INTO "people_temp_alter"( "id", "parent_id", "name", "email", "opt_in", "dob", "address", "github_user", "concessionary_rate_override", "payment_override", "member_of_other_hackspace", "created_date", "end_date") SELECT "id", "parent_id", "name", "email", "opt_in", "dob", "address", "github_user", "concessionary_rate_override", "payment_override", "member_of_other_hackspace", "created_date", "end_date" FROM "people";

DROP TABLE "people";

CREATE TABLE "people" (
  "id" INTEGER PRIMARY KEY NOT NULL,
  "parent_id" integer,
  "name" varchar(255) NOT NULL,
  "email" varchar(255),
  "opt_in" boolean NOT NULL DEFAULT 0,
  "analytics_use" boolean NOT NULL DEFAULT 0,
  "dob" varchar(7) NOT NULL,
  "address" varchar(1024) NOT NULL,
  "github_user" varchar(255),
  "concessionary_rate_override" varchar(255) DEFAULT '',
  "payment_override" float,
  "member_of_other_hackspace" boolean NOT NULL DEFAULT 0,
  "created_date" datetime NOT NULL,
  "end_date" datetime,
  FOREIGN KEY ("parent_id") REFERENCES "people"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "people_idx_parent_id03" ON "people" ("parent_id");

INSERT INTO "people" SELECT "id", "parent_id", "name", "email", "opt_in", "analytics_use", "dob", "address", "github_user", "concessionary_rate_override", "payment_override", "member_of_other_hackspace", "created_date", "end_date" FROM "people_temp_alter";

DROP TABLE "people_temp_alter";




COMMIT;


