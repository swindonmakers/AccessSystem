-- Convert schema './AccessSystem-Schema-9.0-SQLite.sql' to './AccessSystem-Schema-10.0-SQLite.sql':;

BEGIN;

ALTER TABLE "allowed" ADD COLUMN "pending_acceptance" boolean NOT NULL DEFAULT 'true';

CREATE TEMPORARY TABLE "people_temp_alter" (
  "id" INTEGER PRIMARY KEY NOT NULL,
  "parent_id" integer,
  "name" varchar(255) NOT NULL,
  "email" varchar(255),
  "opt_in" boolean NOT NULL DEFAULT 0,
  "dob" varchar(7) NOT NULL,
  "address" varchar(1024) NOT NULL,
  "how_found_us" varchar(50),
  "github_user" varchar(255),
  "telegram_username" varchar(255),
  "telegram_chatid" bigint,
  "google_id" varchar(255),
  "concessionary_rate_override" varchar(255) DEFAULT '',
  "payment_override" float,
  "member_of_other_hackspace" boolean NOT NULL DEFAULT 0,
  "voucher_code" varchar(50),
  "voucher_start" datetime,
  "created_date" datetime NOT NULL,
  "end_date" datetime,
  FOREIGN KEY ("parent_id") REFERENCES "people"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

INSERT INTO "people_temp_alter"( "id", "parent_id", "name", "email", "opt_in", "dob", "address", "how_found_us", "github_user", "telegram_username", "telegram_chatid", "google_id", "concessionary_rate_override", "payment_override", "member_of_other_hackspace", "voucher_code", "voucher_start", "created_date", "end_date") SELECT "id", "parent_id", "name", "email", "opt_in", "dob", "address", "how_found_us", "github_user", "telegram_username", "telegram_chatid", "google_id", "concessionary_rate_override", "payment_override", "member_of_other_hackspace", "voucher_code", "voucher_start", "created_date", "end_date" FROM "people";

DROP TABLE "people";

CREATE TABLE "people" (
  "id" INTEGER PRIMARY KEY NOT NULL,
  "parent_id" integer,
  "name" varchar(255) NOT NULL,
  "email" varchar(255),
  "opt_in" boolean NOT NULL DEFAULT 0,
  "dob" varchar(7) NOT NULL,
  "address" varchar(1024) NOT NULL,
  "how_found_us" varchar(50),
  "github_user" varchar(255),
  "telegram_username" varchar(255),
  "telegram_chatid" bigint,
  "google_id" varchar(255),
  "concessionary_rate_override" varchar(255) DEFAULT '',
  "payment_override" float,
  "member_of_other_hackspace" boolean NOT NULL DEFAULT 0,
  "voucher_code" varchar(50),
  "voucher_start" datetime,
  "created_date" datetime NOT NULL,
  "end_date" datetime,
  FOREIGN KEY ("parent_id") REFERENCES "people"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "people_idx_parent_id03" ON "people" ("parent_id");

CREATE UNIQUE INDEX "telegram_id03" ON "people" ("telegram_chatid");

INSERT INTO "people" SELECT "id", "parent_id", "name", "email", "opt_in", "dob", "address", "how_found_us", "github_user", "telegram_username", "telegram_chatid", "google_id", "concessionary_rate_override", "payment_override", "member_of_other_hackspace", "voucher_code", "voucher_start", "created_date", "end_date" FROM "people_temp_alter";

DROP TABLE "people_temp_alter";


COMMIT;


