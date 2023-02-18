-- Convert schema 'sql/AccessSystem-Schema-11.0-SQLite.sql' to 'sql/AccessSystem-Schema-12.0-SQLite.sql':;

BEGIN;

CREATE TABLE "tiers" (
  "id" INTEGER PRIMARY KEY NOT NULL,
  "name" varchar(50) NOT NULL,
  "description" varchar(2048) NOT NULL DEFAULT '',
  "price" integer NOT NULL,
  "concessions_allowed" boolean NOT NULL DEFAULT 1,
  "dont_use" boolean NOT NULL DEFAULT 0,
  "restrictions" varchar(2048) NOT NULL DEFAULT '{}'
);

CREATE UNIQUE INDEX "tier_name" ON "tiers" ("name");

INSERT INTO tiers (name, description, price, concessions_allowed) values ('Member Of Other Hackspace', 'Living outside of Swindon Borough and a fully paid up member of another Maker or Hackspace', 500, 0);
INSERT INTO tiers (name, description, price, restrictions) values ('Weekend', 'Access 12:00am Saturday until 12:00am Monday, and Wednesdays 6:30pm to 11:59pm only', 1500, '{"times":[{"from":"3:18:00","to":"3:23:59"},{"from":"6:00:01","to":"6:23:59"},{"from":"7:00:01","to":7:23:59"}]}');
INSERT INTO tiers (name, description, price) values ('Standard', 'Access 24hours a day, 365 days a year', 2500);
INSERT INTO tiers (name, description, price) values ('Sponsor', 'Access 24hours a day, 365 days a year', 3500);
INSERT INTO tiers (name, description, price, dont_use) values ('Mens Shed', 'Members of Renew only, rate now retired', 1000, 1);

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
  "tier_id" integer NOT NULL DEFAULT 0,
  "door_colour" varchar(20) NOT NULL DEFAULT 'green',
  "voucher_code" varchar(50),
  "voucher_start" datetime,
  "created_date" datetime NOT NULL,
  "end_date" datetime,
  FOREIGN KEY ("parent_id") REFERENCES "people"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY ("tier_id") REFERENCES "tiers"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

INSERT INTO "people_temp_alter"( "id", "parent_id", "name", "email", "opt_in", "dob", "address", "how_found_us", "github_user", "telegram_username", "telegram_chatid", "google_id", "concessionary_rate_override", "payment_override", "voucher_code", "voucher_start", "created_date", "end_date", "tier_id") SELECT "id", "parent_id", "name", "email", "opt_in", "dob", "address", "how_found_us", "github_user", "telegram_username", "telegram_chatid", "google_id", "concessionary_rate_override", "payment_override", "voucher_code", "voucher_start", "created_date", "end_date", CASE WHEN "people".member_of_other_hackspace ==  1 THEN 1 WHEN "people".concessionary_rate_override == 'mensshed' THEN 5 ELSE 3 END tier_id FROM "people";

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
  "tier_id" integer NOT NULL DEFAULT 0,
  "door_colour" varchar(20) NOT NULL DEFAULT 'green',
  "voucher_code" varchar(50),
  "voucher_start" datetime,
  "created_date" datetime NOT NULL,
  "end_date" datetime,
  FOREIGN KEY ("parent_id") REFERENCES "people"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY ("tier_id") REFERENCES "tiers"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "people_idx_parent_id03" ON "people" ("parent_id");

CREATE INDEX "people_idx_tier_id03" ON "people" ("tier_id");

CREATE UNIQUE INDEX "telegram_id03" ON "people" ("telegram_chatid");

INSERT INTO "people" SELECT "id", "parent_id", "name", "email", "opt_in", "dob", "address", "how_found_us", "github_user", "telegram_username", "telegram_chatid", "google_id", "concessionary_rate_override", "payment_override", "tier_id", "door_colour", "voucher_code", "voucher_start", "created_date", "end_date" FROM "people_temp_alter";

DROP TABLE "people_temp_alter";


COMMIT;


