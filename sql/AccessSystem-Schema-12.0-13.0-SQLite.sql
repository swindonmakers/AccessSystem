-- Convert schema 'sql/AccessSystem-Schema-12.0-SQLite.sql' to 'sql/AccessSystem-Schema-13.0-SQLite.sql':;

BEGIN;

CREATE TEMPORARY TABLE "tiers_temp_alter" (
  "id" INTEGER PRIMARY KEY NOT NULL,
  "name" varchar(50) NOT NULL,
  "description" varchar(2048) NOT NULL DEFAULT '',
  "price" integer NOT NULL,
  "concessions_allowed" boolean NOT NULL DEFAULT 1,
  "in_use" boolean NOT NULL DEFAULT 1,
  "restrictions" varchar(2048) NOT NULL DEFAULT '{}'
);

INSERT INTO "tiers_temp_alter"( "id", "name", "description", "price", "concessions_allowed", "restrictions") SELECT "id", "name", "description", "price", "concessions_allowed", "restrictions" FROM "tiers";

DROP TABLE "tiers";

CREATE TABLE "tiers" (
  "id" INTEGER PRIMARY KEY NOT NULL,
  "name" varchar(50) NOT NULL,
  "description" varchar(2048) NOT NULL DEFAULT '',
  "price" integer NOT NULL,
  "concessions_allowed" boolean NOT NULL DEFAULT 1,
  "in_use" boolean NOT NULL DEFAULT 1,
  "restrictions" varchar(2048) NOT NULL DEFAULT '{}'
);

CREATE UNIQUE INDEX "tier_name03" ON "tiers" ("name");

INSERT INTO "tiers" SELECT "id", "name", "description", "price", "concessions_allowed", "in_use", "restrictions" FROM "tiers_temp_alter";

DROP TABLE "tiers_temp_alter";


COMMIT;


